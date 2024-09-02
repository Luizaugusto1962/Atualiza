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
"atualizac"  = Contem a configuração referente a empresa                                                   
"atualizap"  = Configuracao do parametro do sistema                                                         
"atualizaj"  = Lista de arquivos principais para dar rebuild.                                               
"atualizat   = Lista de arquivos temporarios a ser excluidos da pasta de dados.                             
              Sao zipados em /backup/Temps-dia-mes-ano-horario.zip                                          
"setup.sh"   = Configurador para criar os arquivos atualizac e atualizap                                    

Menus 

1 - Atualização de Programas Avulsos                                                                               
2 - Atualização de Biblioteca                                                                               
3 - Desatualizando                                                                                          
4 - Versão do Iscobol                                                                                       
5 - Versão do Linux                                                                                         
6 - Ferramentas                                                                                             
                                                                                                            
     1 - Atualização de Programas                                                                           
           1.1 - ON-Line                                                                                    
     Acessa o servidor da SAV via scp com o usuário ATUALIZA                                                
     Faz um backup do programa que esta em uso e salva na pasta ?/sav/tmp/olds                              
     com o nome "Nome do programa-anterior.zip" descompacta o novo no diretório                             
     dos programa e salva o a atualização na pasta ?/sav/tmp/progs.                                         
           1.2 - OFF-Line                                                                                   
     Atualiza o arquivo de programa ".zip" que deve ter sido colocado em ?/sav/tmp.                         
     O processo de atualização e idêntico ao passo acima.                                                   
                                                                                                            
     2 - Atualização de Biblioteca                                                                          
           2.1 - Atualização do Transpc                                                                     
     Atualiza a biblioteca que esta no diretório /u/varejo/trans_pc/ do servidor da SAV.                    
     Faz um backup de todos os programas que esta em uso e salva na pasta ?/sav/tmp/olds                    
     com o nome "backup-(versão Informada).zip" descompacta os novos no diretório                           
     dos programas e salva os zips da biblioteca na pasta ?/sav/tmp/biblioteca mudando a                    
     extensão de .zip para .bkp.                                                                            
           2.2 - Atualização do Savatu                                                                      
     Atualiza a biblioteca que esta no diretório /home/savatu/biblioteca/temp/(diretório                    
     conforme  sistema que esta sendo usado.                                                                
     Mesmo procedimento acima.                                                                              
           2.3 - Atualização  OFF-Line                                                                      
     Atualiza a biblioteca que deve estar salva no diretório ?/sav/tmp                                      
     Mesmo procedimento acima.                                                                              
                                                                                                            
     3 - Desatualizando                                                                                     
           3.1 - Voltar programa Atualizado                                                                 
     Descompacta o arquivo salvo anteriormente em ?/sav/tmp/olds com o nome de ("programa"-anterior.zip)    
     na pasta dos programas.                                                                                
                                                                                                            
           3.2 - Voltar antes da Biblioteca                                                                 
     Descompacta o arquivo salvo anteriormente em ?/sav/tmp/olds com nome ("backup-Versão da biblioteca".zip
     na pasta dos programas.                                                                                
                                                                                                            
     4 - Versão do Iscobol                                                                                  
           Verifica qual a Versão do iscobol que esta sendo usada.                                          
                                                                                                            
     5 - Versão do Linux                                                                                    
           Verifica qual o Linux em uso.                                                                    
                                                                                                            
     6 - Ferramentas                                                                                        
          6.1 - Limpar Temporários                                                                          
              6.1.1 - Le os arquivos da lista "atualizat" compactando na pasta ?/sav/tmp/backup             
                      com o nome de Temp(dia+mes+ano) e excluindo da pasta de dados.                        
              6.1.2 - Adiciona arquivos no "ATUALIZAT"                                                      
                                                                                                            
          6.2 - Recuperar arquivos                                                                          
              6.2.1 - Um arquivo ou Todos                                                                   
                  Opção pede para informa um arquivo específico, somente o nome sem a extensão              
                  ou se deixar em branco o nome do arquivo vai recuperar todos os arquivos com as extensões,
                  "*.ARQ.dat" "*.DAT.dat" "*.LOG.dat" "*.PAN.dat"                                           
                                                                                                            
              6.2.2 - Arquivos Principais                                                                   
                  Roda o Jtuil somente nos arquivos que estão na lista "atualizaj"                          
                                                                                                            
          6.3 - Backup da base de dados                                                                     
              6.3.1 - Faz um backup da pasta de dados  e tem a opção de enviar para a SAV                   
              6.3.2 - Restaura Backup da base de dados                                                      
              6.3.3 - Enviar Backup selecionado                                                             
                                                                                                            
          6.4 - Envia e Recebe Arquivos "Avulsos"                                                           
              6.4.1 - Enviar arquivo(s)                                                                     
              6.4.2 - Receber arquivo(s)                                                                                                                         
                                                                                                            
          6.5 - Expurgador de arquivos                                                                      
              Excluir, zips e bkps com mais de 30 dias processado dos diretórios:                           
               /backup, /olds /progs e /logs                                                                
                                                                                                            
          6.7 - Parâmetros                                                                                  
                Variáveis e caminhos necessários para o funcionamento do atualiza.sh                         
                                                                                                            
          6.8 - Update                                                                                      
              Atualização do programa atualiza.sh                                                           
                                                                                                            
