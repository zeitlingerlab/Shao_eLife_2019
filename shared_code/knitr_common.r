### Script for changing knitr default settings
library(pander)
panderOptions("table.split.table", Inf)

figure_path <- function(filename="") {
  file.path(getOption("knitr.figure_dir"), filename)
}

# Format number with commas
pn <- function(i, ...) {
  prettyNum(i, big.mark=",", ...)
}

# Wrap output and code
options(width=80)

# Force knitr to stop evaluation when an error is encountered
knitr::opts_chunk$set(error=FALSE)

# Don't show code blocks by default
knitr::opts_chunk$set(echo=TRUE)

# Don't show warnings by default
knitr::opts_chunk$set(warning=FALSE)

# Don't show messages by default
knitr::opts_chunk$set(message=FALSE)

# Wrap up code
#knitr::opts_chunk$set(tidy=TRUE, tidy.opts=list(width.cutoff=55))

# Set up figure defaults 
knitr::opts_chunk$set(fig.width=4, fig.height=4, dpi = 300, fig.path=figure_path(), dev=c("png", "pdf"))

# Create output directory if it doesn't exist
if(!file.exists(getOption("knitr.figure_dir"))) dir.create(getOption("knitr.figure_dir"))

