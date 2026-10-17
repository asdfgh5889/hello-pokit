PYTHON ?= python3
.PHONY: build test preview install activate recover status animation clean
build:
	$(PYTHON) tools/build.py
test:
	$(PYTHON) tools/test.py
preview:
	$(PYTHON) tools/manage.py preview
install: build
	$(PYTHON) dist/hello-polkit/tools/manage.py install
activate:
	$(PYTHON) tools/manage.py activate
recover:
	$(PYTHON) tools/manage.py recover
status:
	$(PYTHON) tools/manage.py status
animation:
	$(PYTHON) tools/fetch-reference.py
	uv run --locked --group animation python tools/trace-reference.py
	uv run --locked --group animation python tools/interpolate-motion.py
clean:
	$(PYTHON) -c 'import shutil; shutil.rmtree("dist", ignore_errors=True); shutil.rmtree(".cache", ignore_errors=True)'
