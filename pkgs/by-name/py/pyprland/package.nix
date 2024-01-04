{ lib, fetchFromGitHub, python3Packages }:

python3Packages.buildPythonApplication rec {
  pname = "pyprland";
  version = "1.6.9";
  format = "pyproject";

  disabled = python3Packages.pythonOlder "3.10";

  src = fetchFromGitHub {
    owner = "hyprland-community";
    repo = "pyprland";
    rev = version;
    hash = "sha256-qmITBg9csfCIcyTADUOfEo/Nrou01bXHORQ66+Jvodo=";
  };

  nativeBuildInputs = with python3Packages; [ poetry-core ];

  postInstall = ''
    # file has shebang but cant be run due to a relative import, has proper entrypoint in /bin
    chmod -x $out/${python3Packages.python.sitePackages}/pyprland/command.py
  '';

  pythonImportsCheck = [
    "pyprland"
    "pyprland.common"
    "pyprland.plugins"
    "pyprland.plugins.interface"
  ];

  meta = with lib; {
    mainProgram = "pypr";
    description = "An hyperland plugin system";
    homepage = "https://github.com/hyprland-community/pyprland";
    license = licenses.mit;
    maintainers = with maintainers; [ iliayar ];
    platforms = platforms.linux;
  };
}
