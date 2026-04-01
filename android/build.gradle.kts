allprojects {
    repositories {
        google()
        mavenCentral()
        maven("https://raw.githubusercontent.com/arthenica/ffmpeg-kit/main/maven")
    }

    configurations.all {
        resolutionStrategy {
            force("com.arthenica:ffmpeg-kit-full-gpl:6.0")
        }
    }
}

val newBuildDir: Directory =
        rootProject.layout.buildDirectory
                .dir("../../build")
                .get()

rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}