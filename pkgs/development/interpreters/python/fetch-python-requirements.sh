# the script.py will read this date
pretty=$(python -c '
import os; import dateutil.parser;
try:
  print(int(os.getenv("MAX_DATE")))
except ValueError:
  print(dateutil.parser.parse(os.getenv("MAX_DATE")))
')
echo "selected maximum release date for python packages: $pretty"
# find free port for proxy
proxyPort=$(python -c '\
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.bind(("", 0))
print(s.getsockname()[1])
s.close()')
# start proxy to filter pypi responses
# mitmproxy wants HOME set
# mitmdump == mitmproxy without GUI
HOME=$(pwd) $pythonWithMitmproxy/bin/mitmdump \
  --listen-port "$proxyPort" \
  --ignore-hosts '.*files.pythonhosted.org.*' \
  --script $filterPypiResponsesScript &
proxyPID=$!
# install specified version of pip first to ensure reproducible resolver logic
$pythonBin -m venv .venv
.venv/bin/pip install --upgrade pip==$pipVersion
fetcherPip=.venv/bin/pip
# wait for proxy to come up
while sleep 0.5; do
  timeout 5 curl -fs --proxy http://localhost:$proxyPort http://pypi.org && break
done
mkdir $out
# make pip query pypi through the filtering proxy
$fetcherPip download \
  --no-cache \
  --dest $out \
  --progress-bar off \
  --proxy http://localhost:$proxyPort \
  --trusted-host pypi.org \
  --trusted-host files.pythonhosted.org \
  $pipFlags \
  $onlyBinaryFlags \
  $requirementsFlags

echo "killing proxy with PID: $proxyPID"
kill $proxyPID
# create symlinks to allow files being referenced via their normalized package names
# Example:
#   "$out/werkzeug" will point to "$out/Werkzeug-0.14.1-py2.py3-none-any.whl"
cd $out
for f in $(ls $out); do
  if [[ "$f" == *.whl ]]; then
    pname=$(echo "$f" | cut -d "-" -f 1 | sed -e 's/_/-/' -e 's/\./-/' -e 's/\(.*\)/\L\1/')
  else
    pname=$(echo "${f%-*}" | sed -e 's/_/-/' -e 's/\./-/' -e 's/\(.*\)/\L\1/')
  fi
  echo "linking $pname to $f"
  mkdir "$pname"
  mv "$f" "$pname/$f"
done
