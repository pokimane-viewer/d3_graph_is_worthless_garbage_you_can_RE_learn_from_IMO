import os, subprocess, tempfile, shutil, sys, re, tarfile, zipfile, platform

PYTHON = sys.executable

def run(cmd, env=None):
    subprocess.check_call(cmd if isinstance(cmd, str) else cmd, shell=isinstance(cmd, str), env=env)

def setup_openblas_macos():
    run("brew install gcc openblas cmake pkg-config")
    return subprocess.check_output("brew --prefix openblas", shell=True).decode().strip()

def main():
    env = os.environ.copy()
    system = platform.system()
    openblas = None

    if system == "Darwin":
        openblas = setup_openblas_macos()
    elif system == "Windows":
        print("Windows detected: skipping OpenBLAS setup.")
    else:
        print(f"{system} detected: manual OpenBLAS setup may be required.")

    if openblas:
        env.update({
            "LDFLAGS": f"-L{openblas}/lib",
            "CPPFLAGS": f"-I{openblas}/include",
            "PKG_CONFIG_PATH": f"{openblas}/lib/pkgconfig:{env.get('PKG_CONFIG_PATH','')}",
            "CFLAGS": f"-I{openblas}/include",
            "FFLAGS": f"-I{openblas}/include"
        })

    tmp = tempfile.mkdtemp()
    try:
        os.chdir(tmp)
        run([PYTHON, "-m", "pip", "download", "--no-binary=:all:", "--no-deps", "d3graph"], env=env)
        sdist = next((f for f in os.listdir() if re.search(r'\.(tar\.gz|zip)$', f) and f.startswith("d3graph-")), None)
        if not sdist:
            sys.exit("d3graph source not found")

        if sdist.endswith(".tar.gz"):
            with tarfile.open(sdist, "r:gz") as tf:
                tf.extractall()
        else:
            with zipfile.ZipFile(sdist) as zf:
                zf.extractall()

        pkg_dir = next(d for d in os.listdir() if os.path.isdir(d) and d.startswith("d3graph-"))
        os.chdir(pkg_dir)

        if os.path.isfile("requirements.txt"):
            with open("requirements.txt", "r+", encoding="utf-8") as f:
                data = f.read()
                f.seek(0)
                f.truncate()
                f.write(re.sub(r'\bsklearn\b', 'scikit-learn', data))

        run([PYTHON, "-m", "pip", "install", "."], env=env)
    finally:
        os.chdir("/")
        shutil.rmtree(tmp, ignore_errors=True)

if __name__ == "__main__":
    main()






