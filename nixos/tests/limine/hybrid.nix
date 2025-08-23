{ lib, pkgs, ... }:
{
  name = "hybrid";
  meta = {
    inherit (pkgs.limine.meta) maintainers;
  };

  nodes =
    let
      common = {
        boot.loader.limine.enable = true;
        boot.loader.limine.efiSupport = true;
        boot.loader.limine.biosSupport = true;
        boot.loader.timeout = 0;
      };
    in
      {
        uefi = { ... }: {
          imports = [ common ];
          virtualisation.useBootLoader = true;
          virtualisation.useEFIBoot = true;
          boot.loader.efi.canTouchEfiVariables = true;
        };
        mbr = { ... }: {
          imports = [ common ];
          virtualisation.useBootLoader = true;
          virtualisation.useBIOSBoot = true;

        };
      };
  testScript = ''
    for machine in machines:
        machine.start()
        with subtest(f'{machine.name} boots correctly'):
            machine.wait_for_unit('multi-user.target')
  '';
}
