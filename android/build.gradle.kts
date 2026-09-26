allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.projectDirectory.dir("../build")
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

rootProject.extra.set("kotlin_version", "2.3.0")

subprojects {
    configurations.all {
        resolutionStrategy {
            eachDependency {
                if (requested.group == "org.jetbrains.kotlin") {
                    useVersion("2.3.0")
                }
                // Force stdlib alignment
                if (requested.group == "org.jetbrains.kotlin" && requested.name.startsWith("kotlin-stdlib")) {
                    useVersion("2.3.0")
                }
                // Force stable AndroidX versions to avoid AGP 8.9+ requirements from experimental versions
                if (requested.group == "androidx.core" && (requested.name == "core" || requested.name == "core-ktx")) {
                    useVersion("1.13.1")
                }
                if (requested.group == "androidx.browser" && requested.name == "browser") {
                    useVersion("1.8.0")
                }
                if (requested.group == "androidx.activity" && (requested.name == "activity" || requested.name == "activity-ktx")) {
                    useVersion("1.9.3")
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
