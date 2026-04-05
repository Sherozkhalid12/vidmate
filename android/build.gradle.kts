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

// Ensure Agora library has the AndroidX resources it references during release builds.
subprojects {
    if (project.name == "agora_rtc_engine") {
        plugins.withId("com.android.library") {
            dependencies {
                add("implementation", "androidx.appcompat:appcompat:1.6.1")
                add("implementation", "androidx.core:core-ktx:1.13.1")
            }
        }
    }
}


tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
