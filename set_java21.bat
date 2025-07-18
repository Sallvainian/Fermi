@echo off
setx JAVA_HOME "C:\Program Files\Java\jdk-21"
setx PATH "%JAVA_HOME%\bin;%PATH%"
echo Java 21 has been set as default
echo Please restart VS Code after running this script