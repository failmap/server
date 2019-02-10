all: ../puppet/modules/base/files/servertool

src=$(wildcard *.go)

servertool-darwin-amd64: gopath/ ${src}
	GOOS=darwin GOARCH=amd64 GOPATH=$$PWD/gopath GOBIN=$$PWD/gopath/bin go build -o $@

servertool-linux-amd64: gopath/ ${src}
	GOOS=linux GOARCH=amd64 GOPATH=$$PWD/gopath GOBIN=$$PWD/gopath/bin go build -o $@

../puppet/modules/base/files/servertool: servertool-linux-amd64
	cp $< $@

gopath/: ${src}
	GOPATH=$$PWD/gopath GOBIN=$$PWD/gopath/bin go get
	touch $@

mrproper:
	rm -rf gopath/