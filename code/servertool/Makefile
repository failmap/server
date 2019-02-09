all: ../puppet/modules/base/files/servertool

src=$(wildcard *.go)

servertool-darwin-amd64: gopath/ ${src}
	GOOS=darwin GOARCH=amd64 go build -o $@

servertool-linux-amd64: gopath/ ${src}
	GOOS=linux GOARCH=amd64 go build -o $@

../puppet/modules/base/files/servertool: servertool-linux-amd64
	cp $< $@

gopath/: ${src}
	go get
	touch $@

mrproper:
	rm -rf gopath/