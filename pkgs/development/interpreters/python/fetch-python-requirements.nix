# fetchPythonRequirements downlaods python packages specified by a list of
# pip-style python requirements
# It also requires a maximum date 'maxDate' being specified.
# The result will be as if `pip download` would have been executed
# at the point in time specified by maxDate.
# This is ensured by putting pip behind a local proxy filtering the
# api responses from pypi.org to only contain files for which the
# release date is lower than the specified maxDate.

{ buildPackages
, cacert
, curl
, lib
, python3
, stdenv
}:
let

  fetchPythonRequirements = {
    # This specifies the python version for which the packages should be downloaded
    # Pip needs to be executed from that specific python version.
    # Pip accepts '--python-version', but this works only for wheel packages.
    python,

    hash,           # hash for the fixed output derivation
    requirements,   # list of strings of specs

    # restrict to binary releases (.whl)
    # this allows buildPlatform independent fetching
    onlyBinary ? false,

    # additional flags for `pip download`.
    # for reference see: https://pip.pypa.io/en/stable/cli/pip_download/
    pipFlags ? [],

    name ? null,

    nameSuffix ? "python-requirements",

    # maximum release date for packages
    maxDate ? throw ''
      'maxDate' must be specified for fetchPythonRequirements.
      Changing this value will affect the output hash
      Example value: "2023-01-01"
    '',
    # It's better to not refer to python.pkgs.pip directly, as we want to reduce
    #   the times we have to update the output hash
    pipVersion ? throw ''
      'pipVersion' must be specified for fetchPythonRequirements.
      Changing this value will affect the output hash
      Example value: "${python3.pkgs.pip.version}"
    '',
  }:
    # specifying `--platform` for pip download is only allowed in combination with `--only-binary :all:`
    # therefore, if onlyBinary is disabled, we must enforce targetPlatform == buildPlatform to ensure reproducibility
    if ! onlyBinary && stdenv.system != stdenv.buildPlatform.system then
      throw ''
        fetchPythonRequirements cannot fetch sdist packages for ${stdenv.system} on a ${stdenv.buildPlatform.system}.
        Either build on a ${stdenv.system} or set `onlyBinary = true`.
      ''
    else
    let
      # map nixos system strings to python platforms
      sysToPlatforms = {
        "x86_64-linux" = [
          "manylinux1_x86_64"
          "manylinux2010_x86_64"
          "manylinux2014_x86_64"
          "linux_x86_64"
        ];
        "x86_64-darwin" =
          lib.forEach (lib.range 0 15) (minor: "macosx_10_${builtins.toString minor}_x86_64");
        "aarch64-linux" = [
          "manylinux1_aarch64"
          "manylinux2010_aarch64"
          "manylinux2014_aarch64"
          "linux_aarch64"
        ];
      };

      platforms =
        if sysToPlatforms ? "${stdenv.system}"
        then sysToPlatforms."${stdenv.system}"
        else
          throw ''
            'binaryOnly' fetching is currently not supported for target ${stdenv.system}.
            You could set 'binaryOnly = false' and execute the build on a ${stdenv.system}.
          '';

      # we use mitmproxy to filter the pypi responses
      pythonWithMitmproxy =
        python3.withPackages (ps: [ ps.mitmproxy ps.python-dateutil ]);

      # fixed output derivation containing downloaded packages,
      # each being symlinked from it's normalized name
      # Example:
      #   "$out/werkzeug" will point to "$out/Werkzeug-0.14.1-py2.py3-none-any.whl"
      self = stdenv.mkDerivation (finalAttrs: {

        # An invalidation hash is embedded into the `name`.
        # This will prevent `forgot to update the hash` scenarios, as any change
        #   in the derivaiton name enforces a re-build.
        name = let
          pythonMajorAndMinorVer = lib.concatStringsSep "."
            (lib.sublist 0 2 (lib.splitString "." python.version));

          requirementsContent =
            if lib.isList finalAttrs.requirements
            then builtins.toString finalAttrs.requirements
            else builtins.readFile finalAttrs.requirements;

          invalidationHash = builtins.hashString "sha256" ''

            # Ignore the python minor version. It should not affect resolution
            ${python.implementation}
            ${pythonMajorAndMinorVer}
            ${stdenv.system}

            # All variables that might influence the output
            ${finalAttrs.MAX_DATE}
            ${finalAttrs.onlyBinaryFlags}
            ${finalAttrs.pipVersion}
            ${finalAttrs.pipFlags}

            # incldue requirements
            ${requirementsContent}
            ${finalAttrs.requirementsFlags}

            # Only hash the content of the python scripts, as the store path
            # changes with every nixpkgs commit
            ${builtins.readFile finalAttrs.filterPypiResponsesScript}
            ${builtins.readFile finalAttrs.buildPhase}
          '';

          namePrefix =
            if name == null
            then ""
            else name + "-";

        in
          "${namePrefix}${nameSuffix}-${invalidationHash}";

        outputHashMode = "recursive";
        outputHashAlgo = "sha256";
        outputHash = hash;

        nativeBuildInputs = [ pythonWithMitmproxy curl cacert ];

        dontUnpack = true;
        dontInstall = true;
        dontFixup = true;

        pythonBin = python.interpreter;
        filterPypiResponsesScript = ./filter-pypi-responses.py;
        inherit pythonWithMitmproxy;
        inherit pipVersion;
        MAX_DATE = builtins.toString maxDate;
        pipFlags = lib.concatStringsSep " " pipFlags;
        onlyBinaryFlags =
          lib.optionalString onlyBinary "--only-binary :all: ${
            lib.concatStringsSep " " (lib.forEach platforms (pf: "--platform ${pf}"))
          }";
        requirements =
          if lib.isList requirements || lib.isPath requirements
          then requirements
          else throw "'requirements' must either be a list or a file";
        requirementsFlags =
          if lib.isList finalAttrs.requirements
          then "${lib.concatStringsSep "\" \"" finalAttrs.requirements}"
          else "-r ${finalAttrs.requirements}";

        buildPhase = ./fetch-python-requirements.sh;
      });
    in self;
in

fetchPythonRequirements
