  # Atualiza 
  
  ## Shell Script para atualizar o sistema da SAV

- Atualiza programas avulsos
- Atualiza Biblioteca
- Volta de programa ou biblioteca
- Limpa arquivos Temporários
- Recupera arquivos avulso ou os principais
  --- 
    Rotina para atualizar programas e bibliotecas da SAV                                            
    Feito por Luiz Augusto   email luizaugusto@sav.com.br 
  ---
  Arquivos de  trabalho:                                                                            
  "atualizac" = Contem a configuracao de diretorios e de qual tipo de                               
                sistema esta sendo utilizado pela a Empresa.                                        
  "atualizaj" = Lista de arquivos principais do sistema. "Usado no menu Ferramentas"                
  " = Lista de arquivos temporarios a ser exclu dos da pasta de dados.                              
                "Usado no menu Ferramentas"                                                         
                                                                                                    
  ### Menus 

  1 - Atualizacao de Programas                                                                      
  2 - Atualizacao de Biblioteca                                                                     
  3 - Desatualizando                                                                                
  4 - Versao do Iscobol                                                                             
  5 - Versao do Linux                                                                               
  6 - Ferramentas                                                                                   
                                                                                                    
       1 - Atualizacao de Programas                                                                 
             1.1 - ON-Line                                                                            
       Acessa o servidor da SAV via scp com o usuario ATUALIZA                                      
       Faz um backup do programa que esta em uso e salva na pasta ?/sav/tmp/olds                    
       com o nome "Nome do programa-anterior.zip" descompacta o novo no diretorio                   
       dos programa e salva o a atualizacao na pasta ?/sav/tmp/progs.                               
             1.2 - OFF-Line                                                                           
       Atualiza o arquivo de programa ".zip" que deve ter sido colocado em ?/sav/tmp.               
       O processo de atualizacao e id ntico ao passo acima.                                         
       2 - Atualizacao de Biblioteca                                                                
             2.1 - Atualizacao do Transpc                                                             
       Atualiza a biblioteca que esta no diretorio /u/varejo/trans_pc/ do servidor da SAV.          
       Faz um backup de todos os programas que esta em uso e salva na pasta ?/sav/tmp/olds          
       com o nome "backup-(versao Informada).zip" descompacta os novos no diretorio                 
       dos programas e salva os zips da biblioteca na pasta ?/sav/tmp/biblioteca mudando a          
       extensao de .zip para .bkp.                                                                  
             2.2 - Atualizacao do Savatu                                                              
       Atualiza a biblioteca que esta no diretorio /home/savatu/biblioteca/temp/(diretorio          
       conforme  sistema que esta sendo usado.                                                      
       Mesmo procedimento acima.                                                                    
             2.3 - Atualizacao9 OFF-Line                                                              
       Atualiza a biblioteca que deve estar salva no diretorio ?/sav/tmp                            
       Mesmo procedimento acima.                                                                    
                                                                                                    
       3 - Desatualizando                                                                           
             3.1 - Voltar programa Atualizado                                                         
       Descompacta o arquivo salvo anteriormente em ?/sav/tmp/olds com o nome de                    
        ("programa"-anterior.zip) na pasta dos programas.                                           
                                                                                                    
             3.2 - Voltar antes da Biblioteca                                                         
       Descompacta o arquivo salvo anteriormente em ?/sav/tmp/olds com nome ("backcup-versao da     
       biblioteca".zip) na pasta dos programas.                                                     
                                                                                                    
       4 - Versao do Iscobol                                                                        
             Verifica qual a versao do iscobol que esta sendo usada.                                
                                                                                                    
       5 - Versao do Linux                                                                          
             Verifica qual o Linux em uso.                                                          
                                                                                                    
       6 - Ferramentas                                                                              
            6.1 - Limpar Temporarios                                                                  
                Le os arquivos da lista "atualizat" compactando na pasta ?/sav/tmp/backup           
                com o nome de Temp(dia+mes+ano) e excluindo da pasta de dados.                      
                                                                                                    
            6.2 - Recuperar arquivos                                                                  
                6.2.1 - Um arquivo ou Todos                                                             
                    Opcao pede para informa um arquivo espec fico, somente o nome sem a extensao    
                    ou se deixar em branco o nome do arquivo vai recuperar todos os arquivos com     as extensões, "*.ARQ.dat" "*.DAT.dat" "*.LOG.dat" "*.PAN.dat"              
                                                                                                    
                6.2.2 - Arquivos Principais                                                             
                    Roda o Jtuil somente nos arquivos que estao na lista "atualizaj"                
                                                                                                    
            6.3 - Backup da base de dados                                                             
                Faz um backup da pasta de dados  e tem a opcao de enviar para a SAV                 
            6.4 - Restaurar Backup da base de dados                                                   
                Volta o backup feito pela opcao acima                                               
            6.5 - Enviar Backup                                                                       
                Enviar ZIP feito pela opcao 3                                                       
            6.6 - Expurgar                                                                            
                Excluir, zips e bkps com mais de 30 dias processado                                 
            6.7 - Update                                                                              
                Atualizacao do programa atualiza.sh                                               
                ---  
                                                                                                    
