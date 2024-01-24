load_syst <- function(path, yr, period, skip, nmax = Inf, sheet = 1) {

  nms_shrt <- c("kapitola_kod", "organizace_nazev",
           "pocet_predst",
           paste0("pocet_predst_", str_pad(c(1:16), 2, side = "left", pad = "0")),
           "pocet_ostat",
           paste0("pocet_ostat_", str_pad(c(1:16), 2, side = "left", pad = "0")),
           "platy_celkem", "pozad_obcanstvi", "pozad_zakazkonkurence"
  )
  nms_long <- c("kapitola_kod", "organizace_nazev",
                "pocet_predst",
                "pocet_predst_M",
                paste0("pocet_predst_", str_pad(c(1:16), 2, side = "left", pad = "0")),
                "pocet_ostat",
                "pocet_ostat_M",
                paste0("pocet_ostat_", str_pad(c(1:16), 2, side = "left", pad = "0")),
                "platy_celkem", "pozad_obcanstvi", "pozad_zakazkonkurence"
  )


  x <- readxl::read_excel(path, sheet = sheet,
                          skip = skip, n_max = nmax)
  if(yr == 2018) x <- x[,-1:-2] # drop hidden stray first column
  new_names <- if(ncol(x) == 39) nms_shrt else nms_long

  names(x) <- new_names
  x$rok <- yr

  print(yr)
  print(path)
  print(period)
  print(sheet)
  print(x[1,] |> as.character())
  print(names(x))
  print(new_names)

  x <- mutate(x, across(3:ncol(x), as.numeric),
              pocet_celkem = pocet_predst + pocet_ostat,
              rok = as.integer(rok),
              date = as.Date(period),
              kapitola_kod = if_else(kapitola_kod == "307*", "307", as.character(kapitola_kod)))

  return(x)

}

compile_data <- function(syst_sluz, syst_prac, kapitoly) {
  bind_rows(syst_sluz |> mutate(vztah = "sluz"),
            syst_prac |> mutate(vztah = "prac")) |>
    mutate(ustredni_organ = !is.na(kapitola_kod),
           plat_prumer = platy_celkem/pocet_celkem/12) |>
    fill(kapitola_kod, .direction = "down") |>
    left_join(kapitoly, by = "kapitola_kod") |>
    relocate(rok, kapitola_kod, kapitola_zkr, organizace_nazev, ustredni_organ,
             vztah, pocet_celkem, plat_prumer) |>
    mutate(organizace_typ = if_else(ustredni_organ, "Ústřední orgán", "Jiné organizace"),
           kapitola_typ = if_else(kapitola_vladni, "Ministerstva a ÚV", "Ostatní kapitoly"))
}

lengthen_data <- function(syst_all) {
  syst_all |>
    pivot_longer(cols = matches("predst_|ostat_"), names_to = "trida", values_to = "pocet") |>
    mutate(trida = str_remove(trida, "pocet_")) |>
    separate(trida, into = c("level", "trida")) |>
    mutate(level_nazev = if_else(level == "predst", "Představení", "Běžní zaměstnanci")) |>
    select(-pocet_predst, -pocet_ostat, -platy_celkem, -pozad_obcanstvi, -pozad_zakazkonkurence,
           -pocet_celkem, -plat_prumer)
}
