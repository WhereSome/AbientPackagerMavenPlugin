package com.gqtian.plugin;

import org.apache.commons.io.FileUtils;
import org.apache.maven.plugin.AbstractMojo;
import org.apache.maven.plugin.MojoExecutionException;
import org.apache.maven.plugins.annotations.Component;
import org.apache.maven.plugins.annotations.LifecyclePhase;
import org.apache.maven.plugins.annotations.Mojo;
import org.apache.maven.plugins.annotations.Parameter;
import org.apache.maven.project.MavenProject;
import org.apache.maven.project.MavenProjectHelper;
import org.codehaus.plexus.archiver.zip.ZipArchiver;

import java.io.File;
import java.net.URL;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.security.CodeSource;
import java.util.stream.Stream;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

/**
 * 自动装配 RHEL 与 Debian 发行版离线部署包的 Maven 插件
 */
@Mojo(name = "package-dist", defaultPhase = LifecyclePhase.PACKAGE)
public class AbientPackageMojo extends AbstractMojo {

    @Parameter(defaultValue = "${project}", readonly = true, required = true)
    private MavenProject project;

    @Component
    private MavenProjectHelper projectHelper;

    /**
     * 是否跳过打包执行
     */
    @Parameter(property = "abient.skip", defaultValue = "false")
    private boolean skip;

    @Override
    public void execute() throws MojoExecutionException {
        if (skip) {
            getLog().info("[Abient-Packager] abient.skip 为 true，跳过 Linux 部署包打包。");
            return;
        }

        try {
            getLog().info("=================================================");
            getLog().info(" [Abient-Packager] 开始生成 Linux 发行版离线部署包");
            getLog().info("=================================================");

            File targetDir = new File(project.getBuild().getDirectory());
            if (!targetDir.exists()) {
                targetDir.mkdirs();
            }

            // 临时解压目录
            File tempScriptsDir = new File(targetDir, ".abient-scripts-temp");
            if (tempScriptsDir.exists()) {
                FileUtils.deleteQuietly(tempScriptsDir);
            }
            tempScriptsDir.mkdirs();

            // 1. 导出插件自身携带的 scripts
            extractEmbeddedScripts(tempScriptsDir);

            // 2. 分别构建 RHEL 和 Debian 发行版 Zip 包
            buildOsPackage("rhel", tempScriptsDir, targetDir);
            buildOsPackage("debian", tempScriptsDir, targetDir);

            // 3. 清理临时目录
            FileUtils.deleteQuietly(tempScriptsDir);

            getLog().info("=================================================");
            getLog().info(" [Abient-Packager] 部署包打包完成！");
            getLog().info("=================================================");
        } catch (Exception e) {
            getLog().error("[Abient-Packager] 打包过程发生异常", e);
            throw new MojoExecutionException("执行部署包打包失败: " + e.getMessage(), e);
        }
    }

    /**
     * 构建单个 OS 发行版的部署 Zip
     *
     * @param osType         发行版类型 (rhel / debian)
     * @param tempScriptsDir 临时脚本根目录
     * @param targetDir      构建输出目录 (target)
     */
    private void buildOsPackage(String osType, File tempScriptsDir, File targetDir) throws Exception {
        String finalName = project.getBuild().getFinalName();
        File zipFile = new File(targetDir, finalName + "-" + osType + "-bin.zip");
        if (zipFile.exists()) {
            FileUtils.deleteQuietly(zipFile);
        }

        ZipArchiver archiver = new ZipArchiver();
        archiver.setDestFile(zipFile);
        archiver.setDefaultFileMode(0644);
        archiver.setDefaultDirectoryMode(0755);

        // A. 添加主程序 JAR 包
        File jarFile = new File(targetDir, finalName + ".jar");
        if (jarFile.exists()) {
            archiver.addFile(jarFile, jarFile.getName(), 0644);
            getLog().info(String.format("[%s] 添加应用主程序: %s", osType, jarFile.getName()));
        } else {
            getLog().warn(String.format("[%s] 未在 target 找到主程序 JAR: %s", osType, jarFile.getName()));
        }

        // B. 添加操作系统运维脚本（.sh 设置为 0755，其他为 0644）
        File osScriptDir = new File(tempScriptsDir, "scripts/" + osType);
        if (osScriptDir.exists()) {
            addDirectoryWithPermissions(archiver, osScriptDir, "");
            getLog().info(String.format("[%s] 注入并赋予 0755 权限的运维脚本", osType));
        } else {
            getLog().warn(String.format("[%s] 未找到对应的脚本资源目录: %s", osType, osScriptDir.getAbsolutePath()));
        }

        // C. 添加配置文件 (application*.yml / properties) 到 config/ 目录
        File classesDir = new File(project.getBuild().getOutputDirectory());
        if (classesDir.exists()) {
            File[] configFiles = classesDir.listFiles((dir, name) ->
                    (name.endsWith(".yml") || name.endsWith(".yaml") || name.endsWith(".properties"))
                            && !name.equals("git.properties"));
            if (configFiles != null) {
                for (File cfg : configFiles) {
                    archiver.addFile(cfg, "config/" + cfg.getName(), 0644);
                }
            }

            // 如果有 git.properties，放置在部署包根目录
            File gitProperties = new File(classesDir, "git.properties");
            if (gitProperties.exists()) {
                archiver.addFile(gitProperties, "git.properties", 0644);
            }
        }

        // D. 添加数据库迁移与文档 (如果存在)
        File dbDir = new File(project.getBasedir(), "src/main/resources/db");
        if (dbDir.exists()) {
            addDirectoryWithPermissions(archiver, dbDir, "db");
        }

        File docsDir = new File(project.getBasedir(), "docs");
        if (docsDir.exists()) {
            addDirectoryWithPermissions(archiver, docsDir, "docs");
        }

        File dockerDir = new File(project.getBasedir(), "docker");
        if (dockerDir.exists()) {
            addDirectoryWithPermissions(archiver, dockerDir, "docker");
        }

        // E. 收集根目录的 README、CHANGELOG
        File baseDir = project.getBasedir();
        File[] docFiles = baseDir.listFiles((dir, name) -> name.startsWith("README") || name.startsWith("CHANGELOG"));
        if (docFiles != null) {
            for (File doc : docFiles) {
                archiver.addFile(doc, doc.getName(), 0644);
            }
        }

        // 执行打包
        archiver.createArchive();

        // 挂载到 Maven 产物体系中
        projectHelper.attachArtifact(project, "zip", osType + "-bin", zipFile);
        getLog().info(String.format("[%s] 成功输出部署包: %s (大小: %d KB)",
                osType, zipFile.getName(), zipFile.length() / 1024));
    }

    /**
     * 递归遍历目录并添加文件，精准控制文件权限与 Linux 风格路径
     */
    private void addDirectoryWithPermissions(ZipArchiver archiver, File sourceDir, String prefix) throws Exception {
        if (!sourceDir.exists()) {
            return;
        }
        Path rootPath = sourceDir.toPath();
        try (Stream<Path> paths = Files.walk(rootPath)) {
            for (Path path : (Iterable<Path>) paths::iterator) {
                if (Files.isRegularFile(path)) {
                    String relative = rootPath.relativize(path).toString().replace('\\', '/');
                    if (relative.endsWith(".gitignore")) {
                        continue;
                    }
                    String destPath = prefix.isEmpty()
                            ? relative
                            : (prefix.endsWith("/") ? prefix + relative : prefix + "/" + relative);
                    int mode = relative.endsWith(".sh") ? 0755 : 0644;
                    archiver.addFile(path.toFile(), destPath, mode);
                }
            }
        }
    }

    /**
     * 导出内嵌在插件包内的脚本文件到本地临时文件系统
     */
    private void extractEmbeddedScripts(File destDir) throws Exception {
        CodeSource codeSource = getClass().getProtectionDomain().getCodeSource();
        if (codeSource == null) {
            getLog().warn("[Abient-Packager] 无法获取插件 CodeSource，尝试通过 ClassLoader 加载");
            return;
        }

        URL location = codeSource.getLocation();
        String path = location.getPath();

        if (path.endsWith(".jar") || path.contains(".jar!")) {
            // 运行在打包后的 jar 模式
            try (ZipInputStream zis = new ZipInputStream(location.openStream())) {
                ZipEntry entry;
                while ((entry = zis.getNextEntry()) != null) {
                    String name = entry.getName();
                    if (name.startsWith("scripts/") && !entry.isDirectory()) {
                        File targetFile = new File(destDir, name);
                        targetFile.getParentFile().mkdirs();
                        Files.copy(zis, targetFile.toPath(), StandardCopyOption.REPLACE_EXISTING);
                    }
                }
            }
        } else {
            // 运行在未打 jar 的 target/classes 目录模式（如本地开发测试）
            File classesRootDir = new File(location.toURI());
            File scriptsSourceDir = new File(classesRootDir, "scripts");
            if (scriptsSourceDir.exists()) {
                FileUtils.copyDirectory(scriptsSourceDir, new File(destDir, "scripts"));
            }
        }
    }
}
