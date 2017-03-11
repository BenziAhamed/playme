# playme
Convert Swift Playgrounds to Markdown


## Installation

Clone this repo or just download the playme.swift file.

In a terminal type:

```sh
chmod +x playme.swift
./playme.swift path_to_your_playground
```

Alternatively

```sh
swift playme.swift path_to_your_playground
```

playme will print converted markdown to the terminal. Redirect its output to a file of your choice. E.g.

```sh
./playme.swift path_to_your_playground > README.md
```

### Extras

You can pass in `--toc` to generate a table of contents compatible with GitHub.

```sh
./playme.swift path_to_your_playground --toc
```

The table of contents will be the first section in the output.
