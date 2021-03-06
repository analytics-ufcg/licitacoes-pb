library(shiny)

source("../lib/plotFunctions.R")
last_event_A <- NULL
last_event_B <- NULL

compara_eventos <-function(event1, event2) {
  if(is.null(event1) || is.null(event2))
    return(FALSE)
  for (i in 1:ncol(event1))
    if (event1[i] != event2[i])
      return(FALSE)
  return(TRUE)
}

max_unid <- function(data){

  unid_max <- data %>%
    group_by(Unid_prod) %>%
    summarise(n = n())

  unidade_max <- unid_max %>%
    filter(n == max(n))

  unidade_max <- unidade_max$Unid_prod

  return(unid_max$Unid_prod)

}

shinyServer <- function(input, output, session) {
  output$keepAlive <- renderText({
    req(input$count)
    paste("keep alive ", input$count)
  })
  
  library(lubridate)
  library(readr)

  notas <-  src_mysql('notas_fiscais', group='ministerio-publico', password=NULL)

  query <- sql('
   SELECT DISTINCT NCM_prod FROM nota_fiscal
  ')

  ncm_cod <- tbl(notas, query) %>%
    collect(n = Inf)

  ncm <- read.csv("../../../utils/dados/NCMatualizada13072017.csv",
                  sep=";",
                  stringsAsFactors = F,
                  colClasses = c(NCM = "character"))


  dados_fornecedores_ncms <- read_csv("../dados/fornecedores_ncms.csv",
                                      locale = locale(encoding = "latin1"))

  # É necessário ter o csv com a tabela nfe
  #nfe_confiavel <- read_csv("../../dados/nfe_confiavel.csv", locale = locale(encoding = "latin1"))

  output$scatter1 <- renderPlotly({
    event_1 <- event_data("plotly_click", source = "A")
    fornecedores_ncms(dados_fornecedores_ncms, event_1)
  })

  dados_nfe <- reactive({
    nfe <- nfe
  })

  output$scatter_atipicos <- renderPlotly({
    event.data <- event_data("plotly_click", source = "A")

    event.data <<- event.data

    if(is.null(event.data) == T) return(NULL)

    forn_selec <- dados_fornecedores_ncms %>%
      filter(CNPJ == event.data$x, round(Atipicidade, 3) == round(event.data$y, 3))

    forn_selec <<- forn_selec

    notas <-  src_mysql('notas_fiscais', group='ministerio-publico', password=NULL)

    template <- ('
    SELECT Valor_unit_prod, NCM_prod, Descricao_do_Produto_ou_servicos, Nome_razao_social_emit,
                  CPF_CNPJ_emit, Nome_razao_social_dest, CPF_CNPJ_dest, Valor_total_da_nota,
                  Data_de_emissao, Unid_prod, Metrica
    FROM nota_fiscal
    WHERE NCM_prod = "%s" AND Confiavel = "TRUE"
  ')

    query <- template %>%
      sprintf(forn_selec$NCM_prod) %>%
      sql()

    nfe <- tbl(notas, query) %>%
      collect(n = Inf) %>%
      left_join(ncm %>% select(NCM, Descricao), by = c("NCM_prod" = "NCM")) %>%
      mutate(Descricao = substr(Descricao, 12, nchar(Descricao))) %>%
      mutate(forn_selected = if_else(CPF_CNPJ_emit == event.data$x, "Selecionado", "Demais"))

    nfe <<- nfe

    unidade <- nfe %>%
      group_by(Unid_prod) %>%
      summarise(n = n())

    unid_max <- unidade %>%
      filter(n == max(n))

    unid_selected <<- unid_max$Unid_prod
    print(paste("UNIDADE", unid_selected))

    fornecedores_ncm_unidades(nfe, forn_selec$NCM_prod)

  })

  output$scatter_boxplot <- renderPlotly({
    event.data <- event_data("plotly_click", source = "A")

    event.data <<- event.data

    if(is.null(event.data) == T) return(NULL)

    nfe_boxplot <- dados_nfe()

    unidade <- nfe_boxplot %>%
      group_by(Unid_prod) %>%
      summarise(n = n())

    unid_max <- unidade %>%
      filter(n == max(n))

    fornecedores_ncm_unidades_boxplot(nfe, forn_selec$NCM_prod)

  })

 output$text <- renderText({
    event_A <- event_data("plotly_click", source = "A")
    event_B <- event_data("plotly_click", source = "B")

    if (is.null(event_B) & is.null(event_A)) {
      return(NULL)
    } else if(!compara_eventos(event_A, last_event_A)){
      nfe_max <- nfe %>%
        filter(CPF_CNPJ_emit == event_A$x)
    } else if(!compara_eventos(event_B, last_event_B)) {
      nfe_max <- nfe %>%
        filter(CPF_CNPJ_emit == event_B$y) %>%
        filter(Unid_prod == event_B$key)
    }

    preco_max <- max(nfe_max$Valor_unit_prod)

    nfe_max <- nfe_max %>%
      filter(Valor_unit_prod == preco_max) %>%
      head(1)
    texto <- paste("O(A) fornecedor(a) ", nfe_max$Nome_razao_social_emit, "forneceu",
                   nfe_max$Descricao, "(", nfe_max$Unid_prod, ") por R$", round(nfe_max$Valor_unit_prod, 2), "para o(a)", nfe_max$Nome_razao_social_dest)
    return(texto)
  })

  output$scatter_vendas <- renderPlotly({
    event.data_vendas <- event_data("plotly_click", source = "B")

    event.data_vendas <<- event.data_vendas

    if(is.null(event.data_vendas) == T) return(NULL)

    nfe_vendas <- nfe %>%
      filter(CPF_CNPJ_emit == event.data_vendas$y) %>%
      group_by(CPF_CNPJ_emit, CPF_CNPJ_dest, Unid_prod) %>%
      summarise(Nome_razao_social_emit = first(Nome_razao_social_emit),
                Nome_razao_social_dest = first(Nome_razao_social_dest),
                NCM_prod = first(NCM_prod),
                Descricao = first(Descricao),
                Preco_medio = mean(Valor_unit_prod))

    nfe_vendas <<- nfe_vendas

    fornecedor_ncm_compradores(nfe_vendas, event.data_vendas$y, levels(as.factor(nfe$NCM_prod)), unid_max$Unid_prod)
  })


  output$tabela <- renderDataTable({
    event_A <- event_data("plotly_click", source = "A")

    event_B <- event_data("plotly_click", source = "B")
    print(event_B)
    if (is.null(event_B) & is.null(event_A)) {
      return(NULL)
    } else if(!compara_eventos(event_A, last_event_A)){
      last_event_A <<- event_A
      nfe_vendas <- nfe %>%
        filter(CPF_CNPJ_emit == event_A$x)
    } else if(!compara_eventos(event_B, last_event_B)) {
      last_event_B <<- event_B
      nfe_vendas <- nfe %>%
        filter(CPF_CNPJ_emit == event_B$y) %>%
        filter(Unid_prod == event_B$key)
    }

    nfe_vendas <- nfe_vendas %>%
      arrange(desc(Valor_unit_prod)) %>%
      select(-c(Metrica, forn_selected)) %>%
      select(CPF_CNPJ_emit, Nome_razao_social_emit, CPF_CNPJ_dest, Nome_razao_social_dest,
             Descricao_do_Produto_ou_servicos, Unid_prod, NCM_prod, Descricao, Valor_unit_prod,
             Valor_total_da_nota, Data_de_emissao)

    names(nfe_vendas) <- c("CPF/CNPJ Emitente", "Nome do Emitente", "CPF/CNPJ Destinatário", "Nome do Destinatário",
                           "Descrição da Nota", "Unidade", "NCM", "Descrição do NCM", "Valor do produto",
                           "Valor total da nota", "Data de emissão da nota")
    nfe_vendas <<- nfe_vendas

    datatable(nfe_vendas,
              options = list(scrollX = TRUE, pageLength = 10))

  })

  output$download1 <- downloadHandler(
    filename = function(){
      paste("export-atipicidade.csv", sep = "")
    },
    content = function(file) {
      write.csv(dados_fornecedores_ncms %>% mutate_all(funs(as.character(.))),
                file, row.names = F)
    },
    contentType = "text/csv"
  )

  output$download2 <- downloadHandler(
    filename = function(){
      paste("export-sumarizacao.csv", sep = "")
    },
    content = function(file) {
      write.csv(nfe %>% select(-forn_selected) %>% mutate_all(funs(as.character(.))),
                file, row.names = F)
    },
    contentType = "text/csv"
  )

  output$download3 <- downloadHandler(
    filename = function(){
      paste("export-fornecedor-comprador.csv", sep = "")
    },
    content = function(file) {
      write.csv(nfe_vendas %>% mutate_all(funs(as.character(.))),
                file, row.names = F)
    },
    contentType = "text/csv"
  )

  observeEvent(input$message_atipicidade, {
    showModal(modalDialog(
      title = p(strong("Atipicidade")),
      p(tags$div(style="text-align:justify",
        tags$p("A ", strong("atipicidade"), " de um fornecedor para um NCM é calculada considerando a distância normalizada entre o preço médio praticado pelo fornecedor e
                o maior preço médio que não é classificado como ponto extremo."),
        tags$p("Essa visualização mostra os fornecedores com ", strong("maiores índices de atipicidade"), " dentre todos os produtos fornecidos em notas fiscais
                destinadas a entidades públicas do Estado da Paraíba. "),
        tags$p("É possível clicar em qualquer ponto para conhecer os fornecedores com maiores preços médios com relação ao produto (NCM) selecionado.")
      )),
      easyClose = TRUE,
      size = "m",
      footer = modalButton("Fechar")
    ))
  })

  observeEvent(input$message_atuacao, {
    showModal(modalDialog(
      title = p(strong("Atuação de fornecedores no produto selecionado")),
      tags$div(style="text-align:justify",
                 tags$p("A primeira visualização mostra os fornecedores com ", strong("preços médios considerados atípicos"), " para o produto selecionado. Para cada unidade um gráfico
diferente é exibido contendo os fornecedores. O fornecedor selecionado na visualização Atipicidade está também destacado aqui em vermelho"),
                 tags$p("A segunda visualização apresenta uma ", strong("sumarização de todos os fornecedores"), " do produto selecionado possibilitando comparar o quão mais caro os fornecedores
      destacados na primeira visualização estão vendendo")
      ),
      easyClose = TRUE,
      size = "m",
      footer = modalButton("Fechar")
    ))
  })}
