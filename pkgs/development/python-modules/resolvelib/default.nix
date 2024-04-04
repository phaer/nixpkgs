{ lib
, buildPythonPackage
, fetchFromGitHub
, setuptools
, commentjson
, pytestCheckHook
}:

buildPythonPackage rec {
  pname = "resolvelib";
  # Currently this package is only used by Ansible and breaking changes
  # are frequently introduced, so when upgrading ensure the new version
  # is compatible with Ansible
  # https://github.com/NixOS/nixpkgs/pull/128636
  # https://github.com/ansible/ansible/blob/devel/requirements.txt

  version = "1.0.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "sarugaku";
    repo = "resolvelib";
    rev = "/refs/tags/${version}";
    hash = "sha256-oxyPn3aFPOyx/2aP7Eg2ThtPbyzrFT1JzWqy6GqNbzM=";
  };

  nativeBuildInputs = [
    setuptools
  ];

  nativeCheckInputs = [
    commentjson
    pytestCheckHook
  ];

  pythonImportsCheck = [
    "resolvelib"
  ];

  meta = with lib; {
    description = "Resolve abstract dependencies into concrete ones";
    homepage = "https://github.com/sarugaku/resolvelib";
    license = licenses.isc;
    maintainers = with maintainers; [ ];
  };
}
