import ../make-test-python.nix ({ lib, pkgs, ... }: {
  name = "healthchecks";

  meta = with lib.maintainers; {
    maintainers = [ phaer ];
  };

  nodes.machine = { ... }: {
    services.healthchecks = {
      enable = true;
      secretKeyFile = pkgs.writeText "secret" ''
        abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789
      '';
    };
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("healthchecks.target")
    machine.wait_until_succeeds("journalctl --since -1m --unit healthchecks --grep Listening")

    with subtest("Home screen loads"):
        machine.succeed(
            "curl -sSfL http://[::1]:8000 | grep 'Mychecks</title>'"
        )
  '';
})
