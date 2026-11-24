library(tidyverse)
library(rvest)
library(ragg)
library(textshaping)
library(systemfonts)
library(ggtext)
library(ggraph)
library(igraph)
library(tidygraph)
library(grid)
library(dendextend)

fontss <- system_fonts()

###########
#doom <- read_html("https://en.wikipedia.org/wiki/Doom_Metal")
#dubstep <- read_html("https://en.wikipedia.org/wiki/Dubstep")

dnb <- read_html("https://en.wikipedia.org/wiki/Drum_and_bass")

SingleScraper <- function(x) {
  #x <- read_html(url)
  
  df <- tibble(
    genrepage = x |> html_element(xpath = '//*[@id="firstHeading"]/span/span') |> html_text(),
    origins = x |> 
      html_element(
        xpath = "//th[contains(text(), 'Stylistic origins')]/following-sibling::td[@class='infobox-data hlist']"
        ) |>
      html_elements("a") |>
      html_text(),
    origins_urls = x |> 
      html_element(
        xpath = "//th[contains(text(), 'Stylistic origins')]/following-sibling::td[@class='infobox-data hlist']"
      ) |>
      html_elements("a") |>
      html_attr(name = "href")
  )
  
  return(df)
  
}


DNBorigins <- SingleScraper(dnb)

level2df <- DNBorigins |>
  mutate(
    fullurl = paste0("https://en.wikipedia.org/", origins_urls)
    ) |>
  filter(!str_detect(origins, "\\["))

# read_html everything first

fetch_pages <- function(urls, delay = 2) {
  pages <- list()
  
  for(i in seq_along(urls)) {
    message("Fetching ", urls[i])
    tryCatch({
      pages[[i]] <- read_html(urls[i])
      Sys.sleep(delay)  # Be respectful
    }, error = function(e) {
      message("Failed: ", urls[i], " - ", e$message)
      pages[[i]] <- NULL  # Store NULL for failed pages
    })
  }
  
  names(pages) <- urls
  return(pages)
}

level2pages <- fetch_pages(level2df$fullurl, delay = 2)

prelevel3 <- map(.x = level2pages, .f = SingleScraper)

#SingleScraper(level2pages$`https://en.wikipedia.org//wiki/Jungle_music`)
unique(level3df$genrepage)
level3df <- bind_rows(prelevel3)

level3df[85,1] <- "darkcore" # absolutely no idea why this one became an NA, but whatever, only one missing

level3df_ <- level3df |>
  filter(!str_detect(origins, "\\["))

groups <- c(unique(level3df_$genrepage)) #groups : between drum and bass and leaves
groups <- str_remove(groups, " music")
groups <- str_to_title(groups)

#######

edges <- bind_rows(
  level2df[,1:2],
  level3df_[,1:2]
)

edges$genrepage <- str_to_title(edges$genrepage)
edges$origins <- str_to_title(edges$origins)

edges$genrepage <- str_remove(edges$genrepage, " Music")
edges$origins <- str_remove(edges$origins, " Music")

#edges_sorted <- edges |>
#  mutate(genrepage = factor(genrepage, levels = c("Drum And Bass", groups[1], groups[3:5], groups[2], groups[6:11]))) |>
#  arrange(genrepage) |>
#  arrange(origins)

#edges1 <- edges |>
#  mutate(group = genrepage) |>
#  select(from = origins, to = genrepage)
edges2 <- edges |>
  mutate(group = genrepage) |>
  select(to = genrepage, from = origins)

#edges2_sorted <- edges_sorted |>
#  mutate(group = genrepage) |>
#  select(to = genrepage, from = origins)


#edges_sorted <- edges2 |>
#  mutate(to = factor(to, levels = c("Drum And Bass", groups[1], groups[3:5], groups[2], groups[6:11])))

g <- graph_from_data_frame(edges2, directed = T)
g2 <- graph_from_data_frame(edges2, directed = T)
#g2_sorted <- graph_from_data_frame(edges2_sorted, directed = T)

layout <- create_layout(g2, layout = 'dendrogram', circular = TRUE)
#layout2 <- create_layout(g2_sorted, layout = 'dendrogram', circular = TRUE)

layout2 <- layout2 %>%
  mutate(
    # Calculate angle (in radians) from center
    angle = atan2(y, x),
    # For text alignment (optional, flips text so it's not upside down)
    hjust = ifelse(angle > pi/2 | angle < -pi/2, 1, 0)
  )

purple <- "purple4"

####### replacing mid-nodes order

#######


ggraph(layout) + 
  coord_fixed(clip = "off") +  # Maintain aspect ratio
  theme_void() +
  theme(
    plot.margin = margin(10,65,10,65, unit = "pt"),
    plot.background = element_rect(fill = purple),
    panel.background = element_rect(fill = radialGradient(c("gold", "orange", "transparent"), r1 = .1, r2 = .5)),
    plot.caption = element_markdown(hjust = 0.5, margin = margin(50, 0, 0, 0, unit = "pt"), color = "yellow", family = "Mouse Memoirs", size = 17),
    plot.title = element_markdown(color = "yellow", size = 54, hjust = .5, margin = margin(10, 0, 63, 0, unit = "pt"), family = "Mouse Memoirs")
  ) +
  geom_edge_link(
    #arrow = arrow(
    #  length = unit(2, 'mm'),
    #  type = "closed"
    #),
    #end_cap = circle(1, 'mm'),
    color = "yellow", 
    linewidth = 1
    ) + 
  #geom_node_point() + 
  geom_node_text(
    aes(
      label = name,
      x = x * 1.025,  # Scale x outward by 10% (push away from center)
      y = y * 1.025,  # Scale y outward by 10%
      angle = ifelse(angle > pi/2 | angle < -pi/2, 
                   (angle * 180/pi) + 180,
                   angle * 180/pi),
      hjust = hjust,
      filter = leaf
  ),
  size = 3.35, color = "gold", family = "Rocknroll One"
  ) +
  geom_node_text(
    data = layout |> filter(name != "Drum And Bass"), aes(label = name, filter = !leaf), color = purple, family = "Pocket Monk", size = 6.3#, label.r = unit(.65, "lines"), label.padding = unit(.35, "lines")
  ) +
  geom_node_text(
    data = layout |> filter(name == "Drum And Bass"), aes(label = "DNB", filter = !leaf), color = purple, family = "Pocket Monk", size = 24#, label.r = unit(.65, "lines"), label.padding = unit(.3, "lines"), linewidth = 0
  ) +
  labs(
    title = "What made<br>Drum and BassssSSSSsssSSSSSs?",
    caption = "Source : Wikipedia | Made by @stevecarufel.bsky.social for the #30DayChartChallenge"
  )
  # Add curved arrow showing flow direction
  # Or add a curved arrow with geom_curve
  