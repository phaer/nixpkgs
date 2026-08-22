{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  kinparse,
  pyspice,
  netlistsvg,
  pytestCheckHook,
  graphviz,
  sexpdata,
  simp-sexp,
  writableTmpDirAsHomeHook,
}:
buildPythonPackage rec {
  pname = "skidl";
  version = "2.2.1";
  format = "setuptools";

  src = fetchFromGitHub {
    owner = "devbisme";
    repo = "skidl";
    tag = "v${version}";
    sha256 = "sha256-7rauFhaLXyZ5SGtEF7qoAbrj/VgP4qpl+BWUeERefb4=";
  };

  propagatedBuildInputs = [
    kinparse
    pyspice
    graphviz
    sexpdata
    simp-sexp
  ];

  # skidl writes its config to $HOME on import (pythonImportsCheck)
  nativeBuildInputs = [ writableTmpDirAsHomeHook ];

  nativeCheckInputs = [
    netlistsvg
    pytestCheckHook
  ];
  # Examples and integration tests require KiCad symbol libraries
  enabledTestPaths = [ "tests/unit_tests" ];

  disabledTests = [
    # require KiCad symbol libraries
    "test_search_1"
    "test_lib_kicad_1"
    "test_lib_kicad_2"
    "test_lib_kicad_top_level_pins"
    # requires network access
    "test_lib_kicad_repository"
  ];

  pythonImportsCheck = [ "skidl" ];

  meta = {
    description = "SKiDL is a module that extends Python with the ability to design electronic circuits";
    mainProgram = "netlist_to_skidl";
    homepage = "https://devbisme.github.io/skidl/";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ matthuszagh ];
  };
}
