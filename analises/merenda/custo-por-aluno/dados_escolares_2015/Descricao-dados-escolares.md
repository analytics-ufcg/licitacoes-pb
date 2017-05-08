# Descrição dos dados escolares

Este documento apresenta uma descrição dos dados escolares utilizados na análise do custo por aluno de merenda na Paraíba.

### Fonte

Os dados foram obtidos através do [site](http://cidades.ibge.gov.br/xtras/uf.php?lang=&coduf=25&search=paraiba) Cidades do IBGE. Foram obtidos 223 arquivos no formato csv, cada arquivo corresponde aos dados de um município da Paraíba.

### Manipulação

Uma função foi aplicada aos dados(todos os arquivos) para extrair as variáveis necessárias para a análise e as informações forams concatenadas em uma única tabela(no formato csv). A função utilizada encontra-se no repositório do github do projeto.

### Descrição das variáveis

Cada observação na tabela corresponde a um município no estado da Paraíba totalizando 223 municípios. Os dados são referentes apenas ao ano de 2015 que é o mais recente disponibilizado pelo IBGE.

*Todos os dados se referem a escolas públicas municipais.*

* cidade - Nome da cidade correspondente aos dados escolares.
* codcidade - Código da cidade utilizado pelo IBGE
* ano - Ano correspondente aos dados escolares.

* docfund - Número de docentes no ensino fundamental.
* docmed - Número de docentes no ensino médio.
* docpre - Número de docentes no ensino pré-escolar.
* doctotal - Número total de docentes.

* escfund - Número de escolas no ensino fundamental.
* escmed - Número de escolas no ensino médio.
* escpre - Número de escolas no ensino pré-escolar.
* esctotal - Número total de escolas.

* matrifund - Número de matrículas no ensino fundamental.
* matrimed - Número de matrículas no ensino médio.
* matripre - Número de matrículas no ensino pré-escolar.
* matritotal - Número total de matrículas.