  # Atualiza
  ## Shell Script para atualizar o sistema da SAV

- Atualiza programas avulsos
- Atualiza Biblioteca
- Volta de programa ou biblioteca
- Limpa arquivos Temporários
- Recupera arquivos avulso ou os principais

    
    Rotina para atualizar programas e bibliotecas da SAV                                                           
    Feito por Luiz Augusto   
    email luizaugusto@sav.com.br                                                          
    Versão do atualiza.sh                                                                                          
 
  Arquivos de trabalho:  

  "atualizac" = Contem a configuração de diretórios e de qual tipo de                                              
                sistema esta sendo utilizado pela a Empresa.                                                       
  "atualizaj" = Lista de arquivos principais do sistema. "Usado no menu Ferramentas"                               
  " = Lista de arquivos temporários a ser excluídos da pasta de dados.                                             
                "Usado no menu Ferramentas"                                                                        
                                                                                                                   
### Menus
  1 - Atualização de Programas                                                                                     
  2 - Atualização de Biblioteca                                                                                    
  3 - Desatualizando                                                                                               
  4 - Versão do Iscobol                                                                                            
  5 - Versão do Linux                                                                                              
  6 - Ferramentas                                                                                                  
                                                                                                                   
       1 - Atualização de Programas                                                                                
             1 - On-line                                                                                           
       Acessa o servidor da SAV via scp com o usuário ATUALIZA                                                     
       Faz um backup do programa que esta em uso e salva na pasta ?/sav/tmp/olds                                   
       com o nome "Nome do programa-anterior.zip" descompacta o novo no diretório                                  
       dos programa e salva o a atualização na pasta ?/sav/tmp/progs.                                              
             2 - Off-line                                                                                          
       Atualiza o arquivo de programa ".zip" que deve ter sido colocado em ?/sav/tmp.                              
       O processo de atualização e idêntico ao passo acima.                                                        
       2 - Atualização de Biblioteca                                                                               
             1 - Atualização do Transpc                                                                            
       Atualiza a biblioteca que esta no diretório /u/varejo/trans_pc/ do servidor da SAV.                         
       Faz um backup de todos os programas que esta em uso e salva na pasta ?/sav/tmp/olds                         
       com o nome "backup-(versão Informada).zip" descompacta os novos no diretório                                
       dos programas e salva os zips da biblioteca na pasta ?/sav/tmp/biblioteca mudando a                         
       extensão de .zip para .bkp.                                                                                 
             2 - Atualização do Savatu                                                                             
       Atualiza a biblioteca que esta no diretório /home/savatu/biblioteca/temp/(diretório                         
       conforme  sistema que esta sendo usado.                                                                     
       Mesmo procedimento acima.                                                                                   
             3 - Atualizacao9 Offline                                                                             
       Atualiza a biblioteca que deve estar salva no diretório ?/sav/tmp                                           
       Mesmo procedimento acima.                                                                                   
                                                                                                                   
       3 - Desatualizando                                                                                          
             1 - Voltar programa Atualizado                                                                        
       Descompacta o arquivo salvo anteriormente em ?/sav/tmp/olds com o nome de ("programa"-anterior.zip)         
       na pasta dos programas.                                                                                     
                                                                                                                   
             2 - Voltar antes da Biblioteca                                                                        
       Descompacta o arquivo salvo anteriormente em ?/sav/tmp/olds com nome ("backcup-versao da biblioteca".zip)   
       na pasta dos programas.                                                                                     
                                                                                                                   
       4 - Versão do Iscobol                                                                                       
             Verifica qual a versão do iscobol que esta sendo usada.                                               
                                                                                                                   
       5 - Versão do Linux                                                                                         
             Verifica qual o Linux em uso.                                                                         
                                                                                                                   
       6 - Ferramentas                                                                                             
            1 - Limpar Temporários                                                                                 
                Le os arquivos da lista "atualizat" compactando na pasta ?/sav/tmp/backup                          
                com o nome de Temp(dia+mes+ano) e excluindo da pasta de dados.                                     
                                                                                                                   
            2 - Recuperar arquivos                                                                                 
                1 - Um arquivo ou Todos                                                                            
                    Opção pede para informa um arquivo especifico, somente o nome sem a extensão                   
                    ou se deixar em branco o nome do arquivo vai recuperar todos os arquivos com as extensões,     
                    "*.ARQ.dat" "*.DAT.dat" "*.LOG.dat" "*.PAN.dat"                                                
                                                                                                                   
                2 - Arquivos Principais                                                                            
                    Roda o Jutil somente nos arquivos que estão na lista "atualizaj"                               
                                                                                                                   
            3 - Backup da base de dados                                                                            
                Faz um backup da pasta de dados  e tem a opção de enviar para a SAV                                
            
            4 - Restaurar Backup da base de dados         
                Volta o backup feito pela opção acima
                
            5 - Enviar Backup    
                Enviar ZIP feito pela opção 3
                
            6 - Expurgar                                           
                Excluir, zips e bkps com mais de 30 dias processado                                                
            
            7 - Update 
                Atualização do programa atualiza.sh                                                              



## Autores

- [@Luizaugusto1962](https://github.com/Luizaugusto1962)

