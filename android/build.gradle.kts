allprojects {
    repositories {
        google()
        mavenCentral()
    }
    tasks.matching { it.name.contains("AarMetadata") }.configureEach {
        enabled = false
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

subprojects {
    afterEvaluate {
        // Tắt checkReleaseAarMetadata cho các plugin cũ như flutter_quick_video_encoder
        tasks.matching { it.name.contains("AarMetadata") }.configureEach {
            enabled = false
        }

        // Tự động nâng compileSdk của các plugin con lên tối thiểu 34
        val androidExt = project.extensions.findByName("android")
        if (androidExt != null) {
            try {
                val getCompileSdkVersion = androidExt.javaClass.getMethod("getCompileSdkVersion")
                val currentSdk = getCompileSdkVersion.invoke(androidExt)
                val sdkInt = when (currentSdk) {
                    is Int -> currentSdk
                    is String -> currentSdk.filter { it.isDigit() }.toIntOrNull() ?: 0
                    else -> 0
                }
                if (sdkInt in 1..33) {
                    try {
                        val setCompileSdkVersion = androidExt.javaClass.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType)
                        setCompileSdkVersion.invoke(androidExt, 34)
                    } catch (_: Throwable) {
                        val compileSdkVersionMethod = androidExt.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                        compileSdkVersionMethod.invoke(androidExt, 34)
                    }
                }
            } catch (_: Throwable) {}
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

