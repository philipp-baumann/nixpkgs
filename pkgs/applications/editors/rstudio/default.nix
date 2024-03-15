{ lib
, stdenv
#, mkDerivation
, fetchurl
, fetchpatch
, fetchFromGitHub
, makeDesktopItem
, copyDesktopItems
, cmake
, boost183
, icu
, zlib
, openssl
, R
, qtbase # qt6 # qt6
# , libsForQt5
, qmake
, qmake
, qtsensors
, qttools
, qtwebengine
, qtwebchannel
, wrapQtAppsHook
, wrapQtAppsHook
, quarto
, libuuid
, hunspellDicts
, unzip
, ant
, jdk
, gnumake
, pandoc
, llvmPackages
, yaml-cpp
, soci
, postgresql
, nodejs
, mkYarnModules
, fetchYarnDeps
, server ? false # build server version
, sqlite
, pam
, nixosTests
, darwin
, darwin
}:

let
  pname = "RStudio";
  version =
  "${RSTUDIO_VERSION_MAJOR}.${RSTUDIO_VERSION_MINOR}.${RSTUDIO_VERSION_PATCH}${RSTUDIO_VERSION_SUFFIX}";
  RSTUDIO_VERSION_MAJOR  = "2023";
  RSTUDIO_VERSION_MINOR  = "09";
  RSTUDIO_VERSION_PATCH  = "0";
  RSTUDIO_VERSION_SUFFIX = "+463";

  src = fetchFromGitHub {
    owner = "rstudio";
    repo = "rstudio";
    rev = "v${version}";
    hash = "sha256-FwNuU2rbE3GEhuwphvZISUMhvSZJ6FjjaZ1oQ9F8NWc=";
  };

  mathJaxSrc = fetchurl {
    url = "https://s3.amazonaws.com/rstudio-buildtools/mathjax-27.zip";
    hash = "sha256-xWy6psTOA8H8uusrXqPDEtL7diajYCVHcMvLiPsgQXY=";
  };

  rsconnectSrc = fetchFromGitHub {
    owner = "rstudio";
    repo = "rsconnect";
    rev = "5175a927a41acfd9a21d9fdecb705ea3292109f2";
    hash = "sha256-c1fFcN6KAfxXv8bv4WnIqQKg1wcNP2AywhEmIbyzaBA=";
  };

  # Ideally, rev should match the rstudio release name.
  # e.g. release/rstudio-mountain-hydrangea
  quartoSrc = fetchFromGitHub {
    owner = "quarto-dev";
    repo = "quarto";
    rev = "bb264a572c6331d46abcf087748c021d815c55d7";
    hash = "sha256-lZnZvioztbBWWa6H177X6rRrrgACx2gMjVFDgNup93g=";
  };

  description = "Set of integrated tools for the R language";
in
(if server then stdenv.mkDerivation else stdenv.mkDerivation)
  (rec {
    inherit pname version src RSTUDIO_VERSION_MAJOR RSTUDIO_VERSION_MINOR RSTUDIO_VERSION_PATCH RSTUDIO_VERSION_SUFFIX;

    nativeBuildInputs = [
      darwin.apple_sdk.frameworks.CoreServices
      darwin.apple_sdk.frameworks.CoreFoundation
      darwin.apple_sdk.frameworks.Security
      cmake
      wrapQtAppsHook
      boost
      wrapQtAppsHook
      unzip
      ant
      jdk
      pandoc
      nodejs
    ] ++ lib.optionals (!server) [
      copyDesktopItems
    ] ++ lib.optionals stdenv.isDarwin [
      llvmPackages.lld
      darwin.apple_sdk.frameworks.CoreServices
      darwin.apple_sdk.frameworks.CoreFoundation
      darwin.apple_sdk.frameworks.Security
    ];

    buildInputs = [
      boost
      boost183
      openssl
      zlib
      llvmPackages.lld
      zlib
      R
      libuuid
      yaml-cpp
      soci
      postgresql
      quarto
    ] ++ (if server then [
      sqlite.dev
      pam
    ] else [
      icu
      qtbase
      qtxmlpatterns
      qtsensors
      qtwebengine
      qtwebchannel
    ]);

    cmakeFlags = [
      "-DRSTUDIO_TARGET=${if server then "Server" else "Desktop"}"
      "-DRSTUDIO_USE_SYSTEM_SOCI=ON"
      "-DRSTUDIO_USE_SYSTEM_BOOST=ON"
      "-DOPENSSL_ROOT_DIR=${openssl.out}"
      "-DRSTUDIO_USE_SYSTEM_YAML_CPP=ON"
      "-DQUARTO_ENABLED=TRUE"
      "-DPANDOC_VERSION=${pandoc.version}"
      "-DCMAKE_INSTALL_PREFIX=${placeholder "out"}/lib/rstudio"
    ] ++ lib.optionals (!server) [
      "-DQT_QMAKE_EXECUTABLE=${qmake}/bin/qmake"
    ];

    # Hack RStudio to only use the input R and provided libclang.
    patches = [
      ./r-location.patch
      ./clang-location.patch
      ./use-system-node.patch
      ./fix-resources-path.patch
      ./pandoc-nix-path.patch
      ./use-system-quarto.patch
    ];

    postPatch = ''
      substituteInPlace CMakeGlobals.txt \
        --replace-fail 'if(NOT DEFINED HOMEBREW_PREFIX)' 'if(DEFINED HOMEBREW_PREFIX)' \
        --replace-fail 'elseif(APPLE AND UNAME_M STREQUAL arm64)' 'elseif(NOT APPLE AND UNAME_M STREQUAL arm64)'

      substituteInPlace src/cpp/core/r_util/REnvironmentPosix.cpp --replace-fail '@R@' ${R}

      substituteInPlace src/cpp/CMakeLists.txt \
        --replace-fail 'set(Boost_USE_STATIC_LIBS ON)' ' ' \
        --replace-fail 'find_package(OpenSSL REQUIRED)' ' ' \
        --replace-fail "include_directories(SYSTEM \"\''${OPENSSL_INCLUDE_DIR}\")" "include_directories(SYSTEM \"\''${openssl.dev}/include\")" \
        --replace-fail 'find_package(LibR REQUIRED)' ' ' \
        --replace-fail 'cmake_minimum_required(VERSION 3.4.3)' ' ' \
        --replace-fail 'if(NOT APPLE AND RSTUDIO_USE_SYSTEM_SOCI)' 'if(RSTUDIO_USE_SYSTEM_SOCI)'

      substituteInPlace src/cpp/core/CMakeLists.txt \
        --replace-fail 'check_function_exists(inotify_init1 HAVE_INOTIFY_INIT1)' ' ' \
        --replace-fail 'check_symbol_exists(SO_PEERCRED "sys/socket.h" HAVE_SO_PEERCRED)' ' ' \
        --replace-fail 'check_function_exists(setresuid HAVE_SETRESUID)' ' ' \
        --replace-fail 'check_function_exists(group_member HAVE_GROUP_MEMBER)' ' '

       substituteInPlace src/cpp/desktop/CMakeLists.txt \
        --replace-fail 'if(NOT QT_QMAKE_EXECUTABLE)' 'if(QT_QMAKE_EXECUTABLE)' \
        --replace-fail 'elseif(APPLE)' 'elseif(NOT APPLE)'

      substituteInPlace src/gwt/build.xml \
        --replace-fail '@node@' ${nodejs} \
        --replace-fail './lib/quarto' ${quartoSrc}
        --replace-fail '@node@' ${nodejs} \
        --replace-fail './lib/quarto' ${quartoSrc}

      substituteInPlace src/cpp/conf/rsession-dev.conf \
        --replace-fail '@node@' ${nodejs}
        --replace-fail '@node@' ${nodejs}

      substituteInPlace src/cpp/core/libclang/LibClang.cpp \
        --replace-fail '@libclang@' ${llvmPackages.libclang.lib} \
        --replace-fail '@libclang.so@' ${llvmPackages.libclang.lib}/lib/libclang.dylib

      substituteInPlace src/cpp/r/CMakeLists.txt \
        --replace-fail 'target_link_libraries(rstudio-r "-undefined dynamic_lookup")' 'target_link_libraries(rstudio-r \"\''${LIBR_LIBRARIES}\")'
      
      substituteInPlace src/cpp/session/CMakeLists.txt \
        --replace-fail '@pandoc@' ${pandoc} \
        --replace-fail '@quarto@' ${quarto}
        --replace-fail '@pandoc@' ${pandoc} \
        --replace-fail '@quarto@' ${quarto}

      substituteInPlace src/cpp/session/include/session/SessionConstants.hpp \
        --replace-fail '@pandoc@' ${pandoc}/bin \
        --replace-fail '@quarto@' ${quarto}
      
      substituteInPlace src/node/CMakeLists.txt \
        --replace-fail 'cmake_minimum_required(VERSION 3.4.3)' ' '

      substituteInPlace src/node/desktop/CMakeLists.txt \
        --replace-fail 'cmake_minimum_required(VERSION 3.4.3)' ' '
        --replace-fail '@pandoc@' ${pandoc}/bin \
        --replace-fail '@quarto@' ${quarto}
      
      substituteInPlace src/node/CMakeLists.txt \
        --replace-fail 'cmake_minimum_required(VERSION 3.4.3)' ' '

      substituteInPlace src/node/desktop/CMakeLists.txt \
        --replace-fail 'cmake_minimum_required(VERSION 3.4.3)' ' '
    '';

    hunspellDictionaries = with lib; filter isDerivation (unique (attrValues hunspellDicts));
    # These dicts contain identically-named dict files, so we only keep the
    # -large versions in case of clashes
    largeDicts = with lib; filter (d: hasInfix "-large-wordlist" d.name) hunspellDictionaries;
    otherDicts = with lib; filter
      (d: !(hasAttr "dictFileName" d &&
        elem d.dictFileName (map (d: d.dictFileName) largeDicts)))
      hunspellDictionaries;
    dictionaries = largeDicts ++ otherDicts;

    preConfigure =
      lib.optionalString stdenv.isDarwin ''
        export OPENSSL_ROOT_DIR="${openssl.out}"
        export OPENSSL_INCLUDE_DIR="${openssl.dev}/include"
        export OPENSSL_CRYPTO_LIBRARY="${openssl.out}/lib/libcrypto.so"
      '' +
    ''
      mkdir dependencies/dictionaries
      for dict in ${builtins.concatStringsSep " " dictionaries}; do
        for i in "$dict/share/hunspell/"*; do
          ln -s $i dependencies/dictionaries/
        done
      done

      unzip -q ${mathJaxSrc} -d dependencies/mathjax-27

      mkdir -p dependencies/pandoc/${pandoc.version}
      cp ${pandoc}/bin/pandoc dependencies/pandoc/${pandoc.version}/pandoc

      cp -r ${rsconnectSrc} dependencies/rsconnect
      ( cd dependencies && ${R}/bin/R CMD build -d --no-build-vignettes rsconnect )
    '';

    postInstall = ''
      mkdir -p $out/bin $out/share

      ${lib.optionalString (!server) ''
        mkdir -p $out/share/icons/hicolor/48x48/apps
        ln $out/lib/rstudio/rstudio.png $out/share/icons/hicolor/48x48/apps
      ''}

      for f in {${if server
        then "crash-handler-proxy,postback,r-ldpath,rpostback,rserver,rserver-pam,rsession,rstudio-server"
        else "diagnostics,rpostback,rstudio"}}; do
        ln -s $out/lib/rstudio/bin/$f $out/bin
      done

      for f in .gitignore .Rbuildignore LICENSE README; do
        find . -name $f -delete
      done

      rm -r $out/lib/rstudio/{INSTALL,COPYING,NOTICE,README.md,SOURCE,VERSION}
    '';

    meta = {
      # broken = (stdenv.isLinux && stdenv.isAarch64);
      inherit description;
      homepage = "https://www.rstudio.com/";
      license = lib.licenses.agpl3Only;
      maintainers = with lib.maintainers; [ ciil cfhammill ];
      mainProgram = "rstudio" + lib.optionalString server "-server";
      platforms = lib.platforms.linux ++ lib.platforms.darwin;
    };

    passthru = {
      inherit server;
      tests = { inherit (nixosTests) rstudio-server; };
    };
  } // lib.optionalAttrs (!server) {
    qtWrapperArgs = [
      "--suffix PATH : ${lib.makeBinPath [ gnumake ]}"
    ];

    desktopItems = [
      (makeDesktopItem {
        name = pname;
        exec = "rstudio %F";
        icon = "rstudio";
        desktopName = "RStudio";
        genericName = "IDE";
        comment = description;
        categories = [ "Development" ];
        mimeTypes = [
          "text/x-r-source" "text/x-r" "text/x-R" "text/x-r-doc" "text/x-r-sweave" "text/x-r-markdown"
          "text/x-r-html" "text/x-r-presentation" "application/x-r-data" "application/x-r-project"
          "text/x-r-history" "text/x-r-profile" "text/x-tex" "text/x-markdown" "text/html"
          "text/css" "text/javascript" "text/x-chdr" "text/x-csrc" "text/x-c++hdr" "text/x-c++src"
        ];
      })
    ];
  })
