module github.com/jeff/oaks/cli

go 1.24.0

require (
	github.com/mattn/go-sqlite3 v1.14.32
	github.com/santhosh-tekuri/jsonschema/v5 v5.3.1
	github.com/spf13/cobra v1.10.2
	gopkg.in/yaml.v3 v3.0.1
)

require (
	github.com/inconshreveable/mousetrap v1.1.0 // indirect
	github.com/spf13/pflag v1.0.9 // indirect
)

replace github.com/jeff/oaks/api => ../api
