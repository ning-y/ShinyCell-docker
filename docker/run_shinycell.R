#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1) {
  stop("Expected exactly one argument: path to Seurat .rds or .rds.gz file", call. = FALSE)
}

input <- normalizePath(args[[1]], mustWork = TRUE)
if (!grepl("\\.rds(\\.gz)?$", input, ignore.case = TRUE)) {
  stop("Input must end with .rds or .rds.gz", call. = FALSE)
}

if (!requireNamespace("ShinyCell", quietly = TRUE)) {
  stop("R package 'ShinyCell' is not installed in this container", call. = FALSE)
}

if (!requireNamespace("shiny", quietly = TRUE)) {
  stop("R package 'shiny' is not installed in this container", call. = FALSE)
}

if (!requireNamespace("SeuratObject", quietly = TRUE)) {
  stop("R package 'SeuratObject' is not installed in this container", call. = FALSE)
}

obj <- if (grepl("\\.gz$", input, ignore.case = TRUE)) {
  con <- gzfile(input, open = "rb")
  on.exit(close(con), add = TRUE)
  readRDS(con)
} else {
  readRDS(input)
}

if (!inherits(obj, "Seurat")) {
  stop("Input RDS must contain a Seurat object", call. = FALSE)
}

pick_seurat_assay <- function(seu) {
  assay_names <- names(seu@assays)
  assay_candidates <- unique(c(
    SeuratObject::DefaultAssay(seu),
    "RNA",
    "integrated",
    assay_names
  ))
  fallback <- NULL
  slot_priority <- c("data", "counts", "scale.data")

  for (assay_name in assay_candidates) {
    if (!nzchar(assay_name) || !(assay_name %in% assay_names)) {
      next
    }

    assay_obj <- seu@assays[[assay_name]]

    if (inherits(assay_obj, "Assay5")) {
      layer_names <- SeuratObject::Layers(assay_obj)
      for (layer_base in slot_priority) {
        if (!(layer_base %in% layer_names)) {
          matched <- suppressWarnings(SeuratObject::Layers(assay_obj, search = layer_base))
          if (length(matched) > 0L) {
            message(sprintf("Joining '%s' layers in assay '%s' ...", layer_base, assay_name))
            assay_obj <- SeuratObject::JoinLayers(
              object = assay_obj,
              layers = layer_base,
              new = layer_base
            )
            layer_names <- SeuratObject::Layers(assay_obj)
          }
        }
      }

      seu@assays[[assay_name]] <- assay_obj
      layer_names <- SeuratObject::Layers(assay_obj)
      assay_slot <- slot_priority[slot_priority %in% layer_names][1]
    } else {
      has_content <- function(slot_name) {
        if (!(slot_name %in% methods::slotNames(assay_obj))) {
          return(FALSE)
        }
        slot_data <- methods::slot(assay_obj, slot_name)
        dims <- dim(slot_data)
        if (is.null(dims) || length(dims) != 2L) {
          return(FALSE)
        }
        all(dims > 0)
      }
      assay_slot <- slot_priority[vapply(slot_priority, has_content, logical(1))][1]
    }

    if (is.na(assay_slot) || !nzchar(assay_slot)) {
      next
    }

    if (identical(assay_slot, "data")) {
      return(list(obj = seu, assay = assay_name, slot = assay_slot))
    }
    if (is.null(fallback)) {
      fallback <- list(obj = seu, assay = assay_name, slot = assay_slot)
    }
  }

  if (!is.null(fallback)) {
    return(fallback)
  }

  stop(
    "Could not find a usable Seurat assay/layer for ShinyCell. ",
    "Ensure at least one assay has 'data' or 'counts' available."
  )
}

assay_pick <- pick_seurat_assay(obj)
obj <- assay_pick$obj
gex_assay <- assay_pick$assay
gex_slot <- assay_pick$slot
message(sprintf("Using assay '%s' with slot/layer '%s'.", gex_assay, gex_slot))

app_dir <- Sys.getenv("SHINYCELL_APP_DIR", "/srv/shinycell-app")
if (!dir.exists(app_dir)) {
  dir.create(app_dir, recursive = TRUE, showWarnings = FALSE)
}

if (length(list.files(app_dir, all.files = TRUE, no.. = TRUE)) > 0) {
  unlink(file.path(app_dir, "*"), recursive = TRUE, force = TRUE)
}

message("Creating ShinyCell config...")
sc_conf <- ShinyCell::createConfig(obj)

message("Generating ShinyCell app files...")
ShinyCell::makeShinyApp(
  obj = obj,
  scConf = sc_conf,
  gex.assay = gex_assay,
  gex.slot = gex_slot,
  shiny.dir = app_dir,
  shiny.title = sprintf("ShinyCell: %s", basename(input))
)

port <- as.integer(Sys.getenv("SHINYCELL_PORT", "3838"))
if (is.na(port) || port <= 0) {
  port <- 3838L
}

message(sprintf("Starting Shiny app on 0.0.0.0:%d", port))
shiny::runApp(appDir = app_dir, host = "0.0.0.0", port = port, launch.browser = FALSE)
