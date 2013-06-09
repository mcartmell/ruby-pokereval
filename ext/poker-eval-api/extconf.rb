require 'mkmf'
def link_static?
  res = `echo 'int main() { return 0; }' > conftest.c; #{link_command("-Wl,-Bstatic")} 2>&1 | grep -c 'unknown option: -Bstatic'`
	res.to_i == 0
end

$LDFLAGS << " -Wl,-R/usr/local/lib -lpoker-eval -L/usr/local/lib"
$CFLAGS << " -I/usr/include/poker-eval -I/usr/local/include/poker-eval -fPIC -L/usr/local/lib"
have_library "poker-eval"
create_makefile('poker-eval-api/poker-eval-api')
