# k9s

Usage:

```sh
k9s [-c $RESOURCE_TYPE] [-n $NAMESPACE] [--readonly]
# e.g.
# open pod list in the kube-system namespace
k9s -c pods -n kube-system
```

Interface navigation:

- `?` - show the available contextual keyboard shortcuts

- `:` - navigate to a resource type list, enter resource type (you can autocomplete with `TAB`)

  - `ENTER` - search

  - `ESC` - cancel

- `CTRL+a` - show all resource type list

- `/` - search for string in the output, enter string

  - `ENTER` - search

  - `ESC` - cancel

More details: [here](https://k9scli.io/topics/commands/).
