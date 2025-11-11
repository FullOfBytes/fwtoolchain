set -e

# --- CONFIG ---
PREFIX=/opt/fwtoolchain
TARGET=x86_64-elf
JOBS=$(nproc)

BINUTILS_VERSION=2.42
GCC_VERSION=13.2.0

# --- STEP 0: Install prerequisites ---
echo "[*] Installing prerequisites..."

install_deps() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian)
                sudo apt update
                sudo apt install -y build-essential bison flex libgmp3-dev libmpfr-dev libmpc-dev texinfo libisl-dev wget
                ;;
            arch|manjaro)
                sudo pacman -S --needed base-devel bison flex gmp mpfr libmpc texinfo isl wget
                ;;
            fedora)
                sudo dnf install -y @development-tools bison flex gmp-devel mpfr-devel libmpc-devel texinfo isl wget
                ;;
            opensuse*|sles)
                sudo zypper install -y gcc make bison flex gmp-devel mpfr-devel libmpc-devel texinfo isl wget
                ;;
            *)
                echo "Unsupported distribution ($ID). Please install build tools and GMP/MPFR/MPC/ISL manually."
                exit 1
                ;;
        esac
    else
        echo "Cannot detect distribution (missing /etc/os-release)."
        exit 1
    fi
}

install_deps

# --- STEP 1: Build binutils ---
echo "[*] Downloading binutils..."
wget https://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_VERSION.tar.gz
tar xvf binutils-$BINUTILS_VERSION.tar.gz
mkdir -p build-binutils && cd build-binutils

echo "[*] Configuring binutils..."
../binutils-$BINUTILS_VERSION/configure --target=$TARGET --prefix=$PREFIX --disable-nls --disable-werror
sudo make -j$JOBS
sudo make install
cd ..

# --- STEP 2: Build GCC ---
echo "[*] Downloading GCC..."
wget https://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.gz
tar xvf gcc-$GCC_VERSION.tar.gz
mkdir -p build-gcc && cd build-gcc

echo "[*] Configuring GCC..."
../gcc-$GCC_VERSION/configure --target=$TARGET --prefix=$PREFIX --disable-nls --enable-languages=c,c++ --without-headers
sudo make all-gcc -j$JOBS
sudo make all-target-libgcc -j$JOBS
sudo make install-gcc
sudo make install-target-libgcc
cd ..

# --- STEP 3: Create custom names ---
echo "[*] Creating custom tool names..."
cd $PREFIX/bin
sudo ln -sf $TARGET-gcc fwgcc
sudo ln -sf $TARGET-g++ fwg++
sudo ln -sf $TARGET-ld fwld
sudo ln -sf $TARGET-as fwas
sudo ln -sf $TARGET-ar fwar
sudo ln -sf $TARGET-objcopy fwobjcopy
sudo ln -sf $TARGET-objdump fwobjdump
sudo ln -sf $TARGET-nm fwnm

# --- STEP 4: Update PATH ---
echo "[*] Adding $PREFIX/bin to your shell PATH..."

SHELL_NAME=$(basename "$SHELL")

case "$SHELL_NAME" in
    bash)
        RC_FILE="$HOME/.bashrc"
        ;;
    zsh)
        RC_FILE="$HOME/.zshrc"
        ;;
    fish)
        RC_FILE="$HOME/.config/fish/config.fish"
        ;;
    *)
        RC_FILE="$HOME/.profile"
        ;;
esac

if ! grep -q "$PREFIX/bin" "$RC_FILE" 2>/dev/null; then
    if [ "$SHELL_NAME" = "fish" ]; then
        echo "set -gx PATH \$PATH $PREFIX/bin" >> "$RC_FILE"
    else
        echo "export PATH=\$PATH:$PREFIX/bin" >> "$RC_FILE"
    fi
    echo "[*] Added $PREFIX/bin to $RC_FILE"
else
    echo "[*] PATH already configured in $RC_FILE"
fi

echo "[*] fwtoolchain installed successfully!"
echo "Restart your terminal to take effects."
echo "Test: fwgcc --version"
