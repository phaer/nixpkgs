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
    import textwrap

    machine.start()
    machine.wait_for_unit("healthchecks.target")
    machine.wait_until_succeeds("journalctl --since -1m --unit healthchecks --grep Listening")

    with subtest("Home screen loads"):
        machine.succeed(
            "curl -sSfL http://localhost:8000 | grep 'Mychecks</title>'"
        )

    with subtest("Manage script works"):
        # Should fail if not called by healthchecks user
        machine.fail("echo 'print(\"foo\")' | healthchecks-manage help")

        # "shell" sucommand should succeed, needs python in PATH.
        assert "foo\n" = machine.succeed("echo 'print(\"foo\")' | sudo -u healthchecks healthchecks-manage shell")

    with subtest("Creating an admin user works"):
        machine.succeed(
            # this is a non-interactive version of "healthchecks-manage createsuperuser"
            textwrap.dedent("""
            cat <<EOF | sudo -u healthchecks healthchecks-manage shell
            from django.contrib.auth import get_user_model
            User = get_user_model()
            if not User.objects.filter(username='test').exists():
                User.objects.create_superuser('test', 'test@example.com', 'testtest')
            EOF
            """)
        )
  '';
})
