all: ../puppet/modules/base/files/servertool

src=main.go

servertool-darwin-amd64: ${src}
	GOOS=darwin GOARCH=amd64 go build -o $@

servertool-linux-amd64: ${src}
	GOOS=linux GOARCH=amd64 go build -o $@

../puppet/modules/base/files/servertool: servertool-linux-amd64
	cp $< $@