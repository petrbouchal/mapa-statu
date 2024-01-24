library(targets)
library(tarchetypes)
library(future)

# future::plan(multisession)

# Config ------------------------------------------------------------------

options(conflicts.policy = list(warn = FALSE))
conflicted::conflict_prefer("get", "base", quiet = TRUE)
conflicted::conflict_prefer("merge", "base", quiet = TRUE)
conflicted::conflict_prefer("filter", "dplyr", quiet = TRUE)
conflicted::conflict_prefer("lag", "dplyr", quiet = TRUE)
options(clustermq.scheduler = "LOCAL")

cnf <- config::get()
nms_orig <- names(cnf)
names(cnf) <- paste0("c_", names(cnf))
list2env(cnf, envir = .GlobalEnv)
names(cnf) <- names(nms_orig)
rm(nms_orig)

# Set target-specific options such as packages.
tar_option_set(packages = c("dplyr", "tidygraph", "statnipokladna", "here", "readxl", "xml2",
                            "janitor", "curl", "stringr", "conflicted",
                            "future", "tidyr","ragg", "magrittr", "tibble",
                            "furrr", "ggraph", "purrr", "jsonlite", "glue",
                            "lubridate", "writexl", "readr", "ptrr",
                            "pointblank", "tarchetypes", "forcats", "ggplot2"),
               # debug = "compiled_macro_sum_quarterly",
               # imports = c("purrrow"),
)

options(crayon.enabled = TRUE,
        cli.ansi = TRUE,
        scipen = 100,
        statnipokladna.dest_dir = "sp_data",
        czso.dest_dir = "~/czso_data",
        yaml.eval.expr = TRUE)


for (file in list.files("R", full.names = TRUE)) source(file)

suppressMessages(suppressWarnings(source("_targets_packages.R")))

syst_urls <- paste0(c_syst_base_url, "/",
                    stringr::str_replace(c_syst_files_online, "\\.", "-"),
                    ".aspx")
syst_files <- file.path(c_syst_dir, paste0("syst_", c_syst_years, ".xlsx"))


# Orgchart ----------------------------------------------------------------

t_orgchart <- list(
  tar_download(orgdata_xml_fresh, c_orgchart_url, c_orgchart_xml_target),
  tar_target(orgdata_xml, if(c_orgchart_use_local) c_orgchart_xml_local else orgdata_xml_fresh),
  tar_target(urady_tbl, extract_urady(orgdata_xml)),
  tar_target(orgdata_raw, extract_orgdata_raw(orgdata_xml, urady_tbl)),

  tar_target(orgdata_nodes_basic, extract_orgdata_nodes_from_raw(orgdata_raw)),
  tar_target(orgdata_edges, extract_orgdata_edges_from_raw(orgdata_raw)),
  tar_target(orgdata_nodes, annotate_orgdata_nodes(orgdata_nodes_basic)),
  tar_target(orgdata_graph, build_orgdata_graph(orgdata_nodes, orgdata_edges), format = "qs"),

  tar_target(orgdata_nodes_processed, extract_orgdata_nodes_from_graph(orgdata_graph)),
  tar_target(orgdata_edges_processed, extract_orgdata_edges_from_graph(orgdata_graph)),
  tar_target(orgdata_rect, rectangularise_orgdata(orgdata_raw)),
  tar_target(orgdata_date, get_orgdata_date(orgdata_xml))
)

# Export ------------------------------------------------------------------

t_export <- list(
  tar_file(export_org_rect, write_data(orgdata_rect, file.path(c_export_dir, "struktura-hierarchie.csv"),
                                       write_excel_csv2)),
  tar_file(export_org_nodes, write_data(orgdata_nodes_processed,
                                        file.path(c_export_dir, "struktura-nodes.csv"),
                                        write_excel_csv2)),
  tar_file(export_org_edges, write_data(orgdata_edges_processed,
                                        file.path(c_export_dir, "struktura-edges.csv"),
                                        write_excel_csv2))

)

# Generate org pages ------------------------------------------------------

# for static branching below, we need these as objects, not dynamic targets
# so reextract this
# note: perhaps we can do this with dynamic branching instead?

org_tbl <- extract_urady(c_orgchart_xml_local)
org_ids <- make_org_ids(org_tbl)

org_pages <- list(
  tar_file(org_qmd_template, "org_template.qmd"),
  # generate yaml file which will populate the listing on the index page
  tar_file(org_listing_yaml, make_org_listing_yaml(urady_tbl, "org_listing.yaml")),
  # generate a page for each of ~200 orgs
  tar_map(
    values = tibble(org_id = unname(org_ids),
                    org_nazev = names(org_ids)),
    names = org_id,
    tar_target(doc_org, render_org(org_qmd_template, org_id, org_nazev,
                                   profile = "standalone",
                                   # force deps that targets will not detect
                                   # in org_template.qmd
                                   orgdata_graph, orgdata_date, urady_tbl,
                                   # plus to make this run after site generation
                                   doc_html),
               priority = 0.001, format = "file")),
  # generate a page for each of ~200 orgs
  tar_map(
    values = tibble(org_id = unname(org_ids),
                    org_nazev = names(org_ids)),
    names = org_id,
    tar_target(doc_org_pank, render_org(org_qmd_template, org_id, org_nazev,
                                   profile = "pank",
                                   # force deps that targets will not detect
                                   # in org_template.qmd
                                   orgdata_graph, orgdata_date, urady_tbl,
                                   # plus to make this run after site generation
                                   doc_html_pank),
               priority = 0.002, format = "file")
    )
  )

l_pages <- list(
  tar_quarto(doc_html, path = getwd(), extra_files = "org_listing.yaml",
             priority = 0.999, profile = "standalone"),
  tar_quarto(doc_html_pank, path = getwd(), extra_files = "org_listing.yaml",
             priority = 0.998, profile = "pank")
)

# Run ---------------------------------------------------------------------


list(t_export, t_orgchart, org_pages, l_pages)
