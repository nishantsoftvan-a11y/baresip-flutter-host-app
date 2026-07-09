allprojects {
    repositories {
        google()
        mavenCentral()
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
    if (project.name == "file_picker") {
        project.plugins.apply("org.jetbrains.kotlin.android")
        project.tasks.matching { it.name.contains("Kotlin") }.configureEach {
            try {
                val getKotlinOptions = this::class.java.getMethod("getKotlinOptions")
                val kotlinOptions = getKotlinOptions.invoke(this)
                val setJvmTarget = kotlinOptions::class.java.getMethod("setJvmTarget", String::class.java)
                setJvmTarget.invoke(kotlinOptions, "17")
            } catch (e: Exception) {
                // Ignore
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
