extract_urady <- function(path) {
  org_xml <- path
  org_rd <- xml2::read_xml(org_xml)
  org_ls <- org_rd |> xml2::as_list()

  urady <- org_ls$organizacni_struktura_sluzebnich_uradu$UradSluzebniSeznam

  urady_tbl <- urady |>
    map_dfr(function(x) {
      tibble(id = attr(x, "id"),
             urad_nazev = attr(x, "oznaceni"),
             urad_zkratka = attr(x, "zkratka"),
             urad_id_ds = attr(x, "idDS"),
      ) |>
        mutate(urad_skupina =
                 case_when(str_detect(urad_zkratka, "^KHS|^HS HMP") ~ "Hyg. stanice",
                           str_detect(urad_zkratka, "^KVV") ~ "AČR: Krajská velitelství",
                           str_detect(urad_zkratka, "^ÚÚ") ~ "AČR: Újezdní úřady",
                           str_detect(urad_zkratka, "^ZKI|^KÚ|^ČÚZK") ~ "Katastr",
                           str_detect(urad_zkratka, "^(ZA|MZA|SOA|NA)") ~ "Archivy",
                           str_detect(urad_zkratka, "^(S?FÚ)") ~ "Fin. úřady",
                           str_detect(urad_zkratka, "^([MPOČ]SSZ)") ~ "ČSSZ",
                           str_detect(urad_zkratka, "^((O|SÚ)IP)") ~ "Inspekce práce",
                           str_detect(urad_zkratka, "^((O|Č)BÚ)") ~ "Báňské úřady",
                           str_detect(urad_nazev, "^(Ministerstvo|Úřad vlády)") ~ "Ministerstva a ÚV",
                           str_detect(urad_nazev, "[Ff]ond") ~ "Státní fondy",
                           TRUE ~ "Ostatní"))
    })

  return(urady_tbl)
}

extract_orgdata_raw <- function(path, urady_tbl) {
  org_xml <- path
  org_rd <- xml2::read_xml(org_xml)
  org_ls <- org_rd |> xml2::as_list()

  pavouk0 <- org_ls$organizacni_struktura_sluzebnich_uradu
  x0 <- map(pavouk0[3:length(pavouk0)], function(x) {x[["StrukturaOrganizacniPlocha"]]})

  dtt <- future_map_dfr(x0, ~map_dfr(., ~tibble(id = attr(., "id"),
                                                id_ext = attr(., "idExterni"),
                                                parent = attr(., "idNadrizene"),
                                                nazev = attr(., "oznaceni"),
                                                zkratka = attr(., "zkratka"),
                                                predstaveny = attr(., "predstaveny"),
                                                mista_prac = attr(., "mistoPracovniPocet"),
                                                mista_sluz = attr(., "mistoSluzebniPocet")))) |>
    mutate(across(starts_with("mista"), as.numeric)) |>
    replace_na(list(parent = "stat", mista_prac = 0, mista_sluz = 0)) |>
    left_join(urady_tbl |> select(-urad_id_ds), by = "id") |>
    add_row(id = "stat", nazev = "nic", urad_zkratka = "stat", urad_nazev = "nic") |>
    fill(urad_zkratka, urad_nazev, urad_skupina, .direction = "down")

  return(dtt)

}

extract_orgdata_nodes_from_raw <- function(orgdata_raw) {
  orgdata_raw |>
    select(name = id, nazev, mista_prac, mista_sluz, predstaveny, id_ext,
           urad_zkratka, urad_nazev, zkratka, urad_skupina)
}


extract_orgdata_edges_from_raw <- function(orgdata_raw) {
  orgdata_raw |>
    select(to = id, from = parent)
}

annotate_orgdata_nodes <- function(orgdata_nodes_basic) {

  color_palette <- c("black", "#1A1A1A", "#4D4D4D", "#7F7F7F", "#B3B3B3", "#CCCCCC") |> rev()

  orgdata_nodes_basic |>
    mutate(label = nazev,
           analyticky = str_detect(tolower(nazev), "anal|koncep|evalu|progn|expert|výzk|hodnoc|monit"),
           nazev_lower = tolower(nazev),
           categ = case_when(str_detect(nazev_lower, "anal|eval") ~ "Analýzy a evaluace",
                             str_detect(nazev_lower, "hodnocen|dopad") ~ "Hodnocení dopadů",
                             str_detect(nazev_lower, "monitor") ~ "Monitoring",
                             str_detect(nazev_lower, "výzkum") ~ "Výzkum",
                             str_detect(nazev_lower, "strateg|polit|koncep") ~ "Strategie, politiky, koncepce",
                             str_detect(nazev_lower, "statist") ~ "Statistika",
                             .default = "ostatní"),
           color = case_when(str_detect(nazev_lower, "anal|eval") ~ "#8B008B",
                             str_detect(nazev_lower, "hodnocen|dopad") ~ "#006400",
                             str_detect(nazev_lower, "monitor") ~ "#EE7600",
                             str_detect(nazev_lower, "výzkum") ~ "#00008B",
                             str_detect(nazev_lower, "strateg|polit|koncep") ~ "#CD0000",
                             str_detect(nazev_lower, "statist") ~ "#4876FF",
                             .default = "none"))

}

extract_orgdata_edges_from_graph <- function(orgdata_graph, ...) {
  orgdata_graph_jednomini <- orgdata_graph |>
    activate(nodes) |>
    filter(...)

  orgdata_jednomini_nodes <- orgdata_graph_jednomini |>
    activate(nodes) |>
    rename(id = name) |>
    as_tibble()
  orgdata_jednomini_edges <- orgdata_graph_jednomini |>
    activate(edges) |>
    as_tibble() |>
    left_join(orgdata_jednomini_nodes |>
                mutate(from = row_number()) |>
                select(from, from_new = id),
              by = join_by(from)) |>
    left_join(orgdata_jednomini_nodes |>
                mutate(to = row_number()) |>
                select(to, to_new = id),
              by = join_by(to)) |>
    select(-from, -to) |>
    rename(from = from_new, to = to_new)
  return(orgdata_jednomini_edges)
}

extract_orgdata_nodes_from_graph <- function(orgdata_graph, ...) {
  orgdata_graph_jednomini <- orgdata_graph |>
    activate(nodes) |>
    filter(...)

  orgdata_jednomini_nodes <- orgdata_graph_jednomini |>
    activate(nodes) |>
    rename(id = name) |>
    as_tibble()
  return(orgdata_jednomini_nodes)
}

calc_stat <- function(neighborhood, .col, .fn, ...) {
  neighborhood %>% activate(nodes) %>%
    # slice(-1) %>%
    pull({{.col}}) %>%
    .fn()
}

build_orgdata_graph <- function(orgdata_nodes, orgdata_edges) {

  root_id = nrow(orgdata_nodes) + 1

  x <- tbl_graph(orgdata_nodes |> add_row(name = "svet"),
                 orgdata_edges |> replace_na(list(from = "svet")),
                 directed = TRUE) |>
    activate(nodes) |>
    # replace_na(list(mista_sluz = 0, mista_prac = 0)) |>
    mutate(mista_celkem = mista_sluz + mista_prac,
           dpth = bfs_dist(root = root_id),
           child_ftes = map_local_dbl(order = 20, mode= "out",
                                      .f = calc_stat, .col = mista_celkem, .fn = sum)) |>
    activate(edges)

  xx <- dplyr::filter(x, !(from == 1 & to == root_id))
  return(xx)
}

get_orgdata_date <- function(orgdata_xml) {
  dt <- xml2::read_xml(orgdata_xml) |> xml2::as_list()

  dtm <- dt$organizacni_struktura_sluzebnich_uradu$ExportInfo$ExportDatumCas[[1]]
  lubridate::as_datetime(dtm) |> lubridate::as_date()
}
