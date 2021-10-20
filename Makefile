IMAGE := asciinema/asciinema-server

build.docker: submodules
	docker build --tag=$(IMAGE) .

submodules:
	git submodule update --init --recursive
