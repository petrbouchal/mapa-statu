download_ovm <- function(url = "https://rpp-opendata.egon.gov.cz/odrpp/datovasada/ovm.json",
                         file = file.path("data-input", basename(url))) {
  file <- curl::curl_download(url, file)
  return(file)
}

# ovm_file <- download_ovm(file = "data-input/ovm.json")

load_ovm <- function(file) {
  ovm <- jsonlite::read_json(file)
  ovm_df <- ovm$položky |>
    future_map_dfr(function(x) {
      # print(x$`adresa-sídla`)
      tibble(ico = x$ičo,
             nazev_ovm = x$název$cs,
             id_ds = x$`datové-schránky` |> map_chr(`[[`, "identifikátor-ds"),
             id_ovm = x$identifikátor,
             sidlo_adm = as.character(x$`adresa-sídla`['kód']),
             sidlo_adresa = x$`adresa-sídla-txt`,
             # pracoviste = if("pracoviště-ovm" %in% names(x)) x["pracoviště-ovm"] else list(),
             vnitrni = x$`vnitřní-organizační-jednotka`)
    })
  return(ovm_df)
}

# ovm <- load_ovm(ovm_file)

load_adm <- function(files) {
  adm <- future_map_dfr(files,
                        ~read_delim(., delim = ";",
                                    locale = locale(encoding = "Windows-1250",
                                                    decimal_mark = ".", grouping_mark = ","),
                                    name_repair = ~janitor::make_clean_names(.),
                                    col_types = cols(
                                      souradnice_x = "d",
                                      souradnice_y = "d",
                                      plati_od = "_",
                                      .default = "c"
                                    )
                        )
  )

  adm_sf <- st_as_sf(adm |> drop_na(souradnice_x, souradnice_y) |>
                       mutate(souradnice_x = -souradnice_x,
                              souradnice_y = -souradnice_y),
                     coords = c("souradnice_y", "souradnice_x"), crs = 5514) |>
    st_transform(4326)

  adm_coords <- adm_sf |>
    mutate(lon = map_dbl(geometry, `[[`, 1),
           lat = map_dbl(geometry, `[[`, 2)) |>
    st_set_geometry(NULL)

  return(adm_coords)
}


get_adm_files <- function(url = "https://vdp.cuzk.cz/vymenny_format/csv/20220331_OB_ADR_csv.zip",
                          output_file = "data-input/adm.zip") {
  adm_zip <- curl::curl_download(url, output_file)
  files_unzipped <- unzip(adm_zip)
  return(files_unzipped)
}

enrich_ovm <- function(ovm, adm) {
  ovm |>
    left_join(adm, by = c(sidlo_adm = "kod_adm"))
}

# ovm_rich <- enrich_ovm(ovm, adm_coords)
