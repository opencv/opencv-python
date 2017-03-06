wget https://github.com/ninja-build/ninja/releases/download/v1.7.2/ninja-linux.zip -O ninja.zip
unzip ninja.zip
rm ninja.zip
chmod +x ninja
ls -la
export PATH=$PATH:$(pwd)
echo $PATH