$mainClass = if ($args.Count -gt 0) { $args[0] } else { "com.project.Main" }
$jvmArgs = ""
if ($IsMacOS) {
    $jvmArgs = "-XstartOnFirstThread"
}
mvn -PrunMain "-Dexec.mainClass=$mainClass" "-Dexec.jvmArgs=$jvmArgs" clean compile exec:exec
