library(dplyr)

notas <-  src_mysql('notas_fiscais', group='ministerio-publico', password=NULL)

dados_careiros_all <- tbl(notas, 'nota_fiscal') %>%
  select(c(
    Valor_unit_prod, NCM_prod, CPF_CNPJ_dest,
    CPF_CNPJ_emit, Unid_prod, Confiavel)) %>%
  filter(Confiavel == 'TRUE') 

dados_careiros <- dados_careiros_all %>%
  group_by(NCM_prod, CPF_CNPJ_emit, Unid_prod) %>%
  summarise(Preco_medio = mean(Valor_unit_prod)) %>%
  ungroup() %>%
  collect()

dcg_nomes_emit <- tbl(notas, 'nota_fiscal') %>%
  select(CPF_CNPJ_emit, Nome_razao_social_emit) %>%
  collect() %>%
  distinct(CPF_CNPJ_emit, .keep_all = TRUE)

metrica_careiros_unid <- dados_careiros %>%
  filter(!is.na(NCM_prod), NCM_prod != "NA") %>%
  group_by(NCM_prod, Unid_prod) %>%
  mutate(eSobrePreco = (Preco_medio > quantile(Preco_medio, .75) + IQR(Preco_medio) * 1.5)) %>% 
  mutate(Atipico = (Preco_medio - quantile(Preco_medio, 0.75) + IQR(Preco_medio) * 1.5) / IQR(Preco_medio)) %>%
  ungroup() %>%
  filter(!is.nan(Atipico), !is.infinite(Atipico)) 

ncm_temsobrepreco <- metrica_careiros_unid %>% 
  select(NCM_prod, eSobrePreco) %>% 
  group_by(NCM_prod) %>% 
  summarise(NCMTemSobrepreco = any(eSobrePreco))

#dados passados para fornecedores_ncms() devem ter esse formato
metrica_careiros <- metrica_careiros_unid %>%
  group_by(NCM_prod, CPF_CNPJ_emit) %>%
  summarise(Atipicidade = mean(Atipico, na.rm = TRUE)) %>%
  ungroup() %>%
  group_by(CPF_CNPJ_emit) %>%
  mutate(Atipicidade_media = mean(Atipicidade)) %>%
  ungroup() %>%
  mutate(Atipicidade = round(Atipicidade, 6)) %>%
  mutate(Atipicidade_media = round(Atipicidade_media, 6)) %>%
  left_join(dcg_nomes_emit) %>%
  left_join(ncm_temsobrepreco) %>% 
  select(c(CNPJ = CPF_CNPJ_emit,
           Razao_Social = Nome_razao_social_emit,
           NCM_prod,
           Atipicidade,
           Atipicidade_media,
           NCMTemSobrepreco
  ))

write.csv(metrica_careiros, "../dados/fornecedores_ncms.csv", 
          row.names = F, na = "",
          quote = TRUE, fileEncoding = "latin1")




dados_careiros_comp <- dados_careiros_all %>%
  group_by(NCM_prod, CPF_CNPJ_emit, CPF_CNPJ_dest, Unid_prod) %>%
  summarise(Preco_medio = mean(Valor_unit_prod)) %>%
  ungroup() %>%
  collect()  

dcg_nomes_dest <- tbl(notas, 'nota_fiscal') %>%
  select(CPF_CNPJ_dest, Nome_razao_social_dest) %>%
  collect() %>%
  distinct(CPF_CNPJ_dest, .keep_all = TRUE)

#dados passados para fornecedor_ncm_compradores
dados_careiros_comp <- dados_careiros_comp %>%
  filter(!is.na(NCM_prod), NCM_prod != "NA", NCM_prod != "0") %>%
  left_join(dcg_nomes_emit) %>%
  left_join(dcg_nomes_dest) %>%
  mutate(Preco_medio = round(Preco_medio, 2))

write.csv(dados_careiros_comp, "../dados/fornecedor_ncm_compradores.csv", 
          row.names = F, na = "",
          quote = TRUE, fileEncoding = "latin1")


notas <-  src_mysql('notas_fiscais', group='ministerio-publico', password=NULL)

template <- ('
    SELECT Valor_unit_prod, NCM_prod, Unid_prod, Descricao_do_Produto_ou_servicos, Nome_razao_social_emit, 
                  CPF_CNPJ_emit, Nome_razao_social_dest, CPF_CNPJ_dest
    FROM nota_fiscal
    WHERE Confiavel = "TRUE"
  ')

query <- template %>%
  sql()

nfe <- tbl(notas, query) %>%
  collect(n = Inf) 

write.csv(nfe, "../dados/nfe_confiavel.csv", 
          row.names = F, na = "",
          quote = TRUE, fileEncoding = "latin1")