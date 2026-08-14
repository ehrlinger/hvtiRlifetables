## Build data/us_lifetable_models.rda from CCF's fitted .sas7bdat blocks.
##
## MAINTAINED ENTRY POINT, not a one-off migration. CCF refits the US life
## tables periodically -- table2023 was added by Andrew Toth on 2025-12-23.
## Adding a vintage is: drop its directory into data-raw/uslife/, add a row
## to MANIFEST below, re-run this script, bump the PATCH digit, ship.
##
## Run from the package root:  Rscript data-raw/build-models.R
##
## data-raw/uslife/ is gitignored -- the blocks are CCF's and the repo is
## public. They are on disk deliberately: the /Volumes/qhsstudies share is
## unreliable and these files exist nowhere else off it. If they are missing,
## re-copy from /Volumes/qhsstudies/general/uslife/<vintage>/estimates/.

library(haven)

SRC <- "data-raw/uslife"

## The eleven fitted parameters, in the order the .sas7bdat rows carry them.
## This order is also the row/column order of the covariance block.
PARAM_NAMES <- c("DELTA", "THALF", "NU", "M", "TAU", "GAMMA", "ALPHA", "ETA",
                 "E0", "C0", "L0")

## The six leading rows are fitted-form flags, not parameters. They carry
## _STATUS_ = NA. They ship as metadata and are never read by the evaluator:
## the shape parameters plus _STATUS_ fully determine the curve.
FLAG_NAMES <- c("G1FLAG", "FIXDEL0", "FIXMNU1", "G3FLAG", "FIXGE2", "FIXGAE2")

## EXPLICIT manifest. Do NOT replace with list.files() -- table2008 on disk
## also carries hzicall_jr and hzicall_l, which no %usmatchd variant
## references and which must not ship.
MANIFEST <- list(
  table84   = c(all = "hzicall", f  = "hzicf",  m  = "hzicm",
                w   = "hzicw",   o  = "hzico",
                wf  = "hzicwf",  wm = "hzicwm", of = "hzicof", om = "hzicom"),
  table2008 = c(all = "hzicall", f  = "hzicf",  m  = "hzicm",
                w   = "hzicw",   b  = "hzicb",
                wf  = "hzicwf",  wm = "hzicwm", bf = "hzicbf", bm = "hzicbm"),
  table2023 = c(all = "hzicall", f  = "hzicf",  m  = "hzicm",
                w   = "hzicw",   b  = "hzicb",
                wf  = "hzicwf",  wm = "hzicwm", bf = "hzicbf", bm = "hzicbm")
)

read_block <- function(vintage, file) {
  path <- file.path(SRC, vintage, paste0(file, ".sas7bdat"))
  if (!file.exists(path)) {
    stop("missing fitted block: ", path,
         "\nRe-copy from /Volumes/qhsstudies/general/uslife/", vintage,
         "/estimates/", call. = FALSE)
  }
  d <- as.data.frame(read_sas(path))
  rownames(d) <- d[["_NAME_"]]

  if (!all(PARAM_NAMES %in% rownames(d))) {
    stop(path, " is missing parameters: ",
         paste(setdiff(PARAM_NAMES, rownames(d)), collapse = ", "),
         call. = FALSE)
  }
  if (!all(FLAG_NAMES %in% rownames(d))) {
    stop(path, " is missing flags: ",
         paste(setdiff(FLAG_NAMES, rownames(d)), collapse = ", "),
         call. = FALSE)
  }

  status <- as.integer(d[PARAM_NAMES, "_STATUS_"])
  names(status) <- PARAM_NAMES
  ## Loud, because a silent NA here is the _STATUS_ trap in a new disguise.
  if (anyNA(status)) {
    stop(path, " has NA _STATUS_ on a parameter row: ",
         paste(PARAM_NAMES[is.na(status)], collapse = ", "), call. = FALSE)
  }
  if (!all(status %in% c(0L, 1L))) {
    stop(path, " has _STATUS_ outside {0, 1}", call. = FALSE)
  }

  params <- as.numeric(d[PARAM_NAMES, "_EST_"])
  names(params) <- PARAM_NAMES

  flags <- as.numeric(d[FLAG_NAMES, "_EST_"])
  names(flags) <- FLAG_NAMES

  ## Columns 4-14 of the parameter rows are the 11 x 11 covariance block.
  ## Nothing in v1 reads it. It ships because it is the only route to a
  ## confidence band later and it costs bytes.
  vcov <- as.matrix(d[PARAM_NAMES, PARAM_NAMES])
  storage.mode(vcov) <- "double"
  dimnames(vcov) <- list(PARAM_NAMES, PARAM_NAMES)

  list(params = params, status = status, flags = flags, vcov = vcov)
}

rows <- list()
for (vintage in names(MANIFEST)) {
  files <- MANIFEST[[vintage]]
  for (stratum in names(files)) {
    b <- read_block(vintage, files[[stratum]])
    rows[[length(rows) + 1L]] <- data.frame(
      vintage = vintage,
      stratum = stratum,
      params  = I(list(b$params)),
      status  = I(list(b$status)),
      flags   = I(list(b$flags)),
      vcov    = I(list(b$vcov)),
      stringsAsFactors = FALSE
    )
  }
}

us_lifetable_models <- do.call(rbind, rows)
rownames(us_lifetable_models) <- NULL

stopifnot(nrow(us_lifetable_models) == 27L)

save(us_lifetable_models,
     file = "data/us_lifetable_models.rda",
     compress = "xz", version = 3)

cat("wrote data/us_lifetable_models.rda:",
    nrow(us_lifetable_models), "records,",
    format(file.size("data/us_lifetable_models.rda")), "bytes\n")
