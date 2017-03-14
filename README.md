# playme
Convert Swift Playgrounds to Markdown

## Example

This [readme](https://github.com/BenziAhamed/Tracery) was generated using playme.

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

## Usage

```
usage: playme path_to_playground [--toc [--toc-top]] [--no-credits] [update [--check]]

--toc          generate a GitHub compatible TOC at the beginning of the document
--toc-top      generate back to top links before relevant headers
--no-credits   prevent appending credits text at the end

update         updates playme to the latest version
--check        run update availability checks, but does not update

--help         prints usage

visit https://github.com/BenziAhamed/playme
```

## Extras



### TOC generation
You can pass in `--toc` to generate a table of contents compatible with GitHub.

```sh
./playme.swift path_to_your_playground --toc
```

The table of contents will be the first section in the output. 

If you wish to control more precisely where the TOC should be created, add `{{GEN:TOC}}` a line in a _markdown formatted block_ somewhere in your playground. If your plaground has multiple pages, the first page would be the best location, but you can also add one at the end. playme will replace the line containing `{{GEN:TOC}}` with the TOC contents. 

> Only one TOC block will be generated, so placing multiple `{{GEN:TOC}}`s will have no effect, only the first one will be considered.

### Anti Credit Union
Disable appending a credits line at the end by passing in `--no-credits`.

