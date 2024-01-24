render_org <- function(file, org_id, org_nazev, profile = NULL, ...) {
  # quarto::quarto_render(file, execute_params = list(kraj = kraj),
  #                       output_file = paste0("kraj_", kraj, ".html"), quiet = TRUE)
  output_file = paste0("org_", org_id, ".html")

  args <- c("render", file,
            "--execute-param", glue("org_id:{org_id}"),
            "--execute-param", glue("org_nazev:{org_nazev}"),
            "--metadata", glue("pagetitle:{org_nazev}"),
            "--metadata", glue("title:{org_nazev}"),
            "--output", output_file)
  if(!is.null(profile)) args <- c(args, "--profile", profile)

  if(!is.null(profile)) site_dir <- paste0("site", "-", profile) else site_dir <- "site"

  # print(args)

  # print(profile)
  # print(site_dir)

  processx::run("quarto", args = args, echo_cmd = FALSE)
  rslt <- file.path(site_dir, output_file)
  # print(rslt)
  return(rslt)
}

make_org_listing_yaml <- function(urady_tbl, path) {

  org_id <- urady_tbl$id
  path_base = paste0("org", "_", org_id)
  org_name <- urady_tbl$urad_nazev
  org_zkr <- urady_tbl$urad_zkratka
  org_kat <- urady_tbl$urad_skupina

  df <- purrr::pmap(list(path_base, org_name, org_zkr, org_kat),
                    function(a, b, c, d) {

                      list(title = b,
                           href = paste0("", a, ".html"),
                           url = paste0("", a, ".html"),
                           categories = list(d),
                           zkratka = c,
                           link = paste0("<a href =\"", "", a, ".html\">", b, "</a>")
                    )})

  yaml::write_yaml(df, path)
  return(path)
}

make_org_ids <- function(urady_tbl) {
  ids <- urady_tbl$id
  names(ids) <- urady_tbl$urad_nazev
  return(ids)
}
