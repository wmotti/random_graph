require 'rubygems'
require 'rgl/adjacency'
require 'rgl/topsort'
require 'rgl/dot'
require 'gnuplot'

module RGL

  class DirectedAdjacencyGraph
  
    def cyclic?
      !acyclic?
    end

    # restituisce i vertici che precedono v
    def prev_vertices(v)
      self.to_undirected.adjacent_vertices(v) - adjacent_vertices(v)
    end
  end

  # genera un grafo casuale
  #
  class RandomDAG < DirectedAdjacencyGraph

    # genera un grafo casuale
    # parametri:
    # - n -> numero dei vertici
    # - iterations_number -> numero delle transizioni sulla catena di Markov
    # - acyclic -> true se si desidera un grafo aciclico
    # - pbar -> true se si desidera una barra di avanzamento
    # - random -> usa il generatore casuale di ruby se vale 'ruby_rand', il generatore delle librerie GSL se 'gsl_rand'
    # - file -> specifica se salvare su file una rappresentazione grafica del grafo
    def initialize(n, iterations_number, params = {})

      params = { :acyclic => true, :pbar => false, :random => 'ruby_rand', :file => '' }.merge(params)
      # valori di default dei parametri opzionali
      @acyclic = params[:acyclic]
      pbar    = params[:pbar]
      @random  = params[:random]
      file    = params[:file]
      @n = n

      
      if @random == 'gsl_rand'
	# inizializzazione del generatore delle librerie GSL
	require 'rb_gsl'
	seed = (rand*1000).round
	@rng = GSL::Rng.alloc("mt19937", seed)
      end
      
      # chiamata al costruttore della classe DirectedAdjacencyGraph
      super()

      if pbar
	# inizializzazione della barra di avanzamento
	require 'facets/progressbar'
	iterations_pbar = Console::ProgressBar.new("Graph gen", iterations_number)
      end

      # genera il grafo iniziale con lati (i,i+1) per 1 < i < n
      1.upto(n-1) do
          |i| add_edge(i,i+1)
      end # do

      # transizioni sulla catena di Markov
      iterations_number.times do
          transition
          iterations_pbar.inc if pbar
       end # do
       iterations_pbar.finish if pbar

	if !@acyclic
	  # se desidero un grafo ciclico, continuo le transizioni finché necessario
	  transition until cyclic?
	end # if

	# stampa su file una rappresentazione del grafo
	write_to_graphic_file(fmt='png', dotfile=file) if (file != '' and file.is_a?(String))
    end # def initialize

    # effettua una transizione sulla catena di Markov
    def transition
      # estrae i e j con 1 < i != j < n
      i = eval("#{@random}(@n)+1")
      begin
	j = eval("#{@random}(@n)+1")
      end until j != i

      # se l'arco esiste
      if has_edge?(i,j)
	# rimuovilo
	remove_edge(i,j)
	# se la rimozione ha creato un grafo disconnesso
        if disconnected?(i,j)
	  # aggiungilo nuovamente
	  add_edge(j,i)
        end
      else
	# aggiungi l'arco
	add_edge(i,j)
	  # se desidero in output un grafo aciclico e il grafo attuale è ciclico 
	  if @acyclic and cyclic?
	    # rimuovi l'arco appena aggiunto
	    remove_edge(i,j)
          end # if
       end # if
    end # def

    # restituisce il grafo risultato di una transizione
    def next_transition
      transition
      self
    end

    # restituisce un numero casuale ottenuto con il generatore della libreria GSL
    def gsl_rand(n)
      @rng.uniform_int(n)
    end

    # restituisce un numero casuale ottenuto con il generatore standard di ruby
    def ruby_rand(n)
      rand(n)
    end

    # restituisce true se il grafo è connesso
    # in input riceve i vertici appartenenti all'arco che è appena stato rimosso
    def connected?(i,j)
	# un grafo diretto è connesso se lo è il grafo non diretto corrispondente
        ug = to_undirected
	# euristica: dopo aver rimosso il lato (i,j), se i o j non hanno più adiacenti allora il grafo è disconnesso
        if ( ug.adjacent_vertices(i) == []  or ug.adjacent_vertices(j) == [])
            return false
        else
	    ug.bfs_search_tree_from(i).length == ug.num_vertices
        end # if
    end

    # restituisce true se il grafo è disconnesso
    def disconnected?(i,j)
      !connected?(i,j)
    end

    # stampa una rappresentazione grafica del grafo
    def write_to_graphic_file (fmt='png', dotfile='graph')

      # fissa la posizione dei vertici nel caso di grafi con numero di vertici < 5
      position = {1 => "100,200", 
		  2 => "200,200", 
		  3 => "200,100", 
		  4 => "100,100"}
      src = dotfile + ".dot"
      dot = dotfile + "." + fmt

      # scrive il file .dot che permetterà la generazione del grafo
      File.open(src, 'w') do |f|
	f << "digraph #{self.class.name.gsub(/:/,'_').to_s} {\n"
	each_vertex do |v|
	  name = v.to_s
	  f << "    #{name} [\n"
	  f << "        fontsize = 8\n"
	  f << "        label = #{name}\n"
	  if num_vertices < 5
	    f << "        pos = \"#{position[v]}\"\n" 
	  end
	  f << "    ]\n\n"
	end
	each_edge do |u,v|
	  f << "    #{u.to_s} -> #{v.to_s} [\n"
	  f << "        fontsize = 8\n"
	  f << "    ]\n\n"
	end
   	f << "}"
      end
      # se il grafo ha meno di 5 vertici, per la generazione della rappresentazione grafica uso neato (permette di forzare la posizione dei vertici) e non dot
      if num_vertices < 5
	system( "neato -s -n -T#{fmt} #{src} -o #{dot}" ) 
      else
	system( "dot -T#{fmt} #{src} -o #{dot}" ) 
      end
      dot
    end # def
  end # class
end # module

# genera graphs_n grafi con nodes_n nodi effettuando transitions_n transizioni sulla catena di Markov;
# conta il numero di occorrenze di ciascun grafo distinto;
# disegna il grafico delle frequenze
def test(graphs_n, nodes_n, transitions_n, params)
    
    # genera grafi casuali
    # parametri:
    # - graphs_n -> numero dei grafi da generare
    # - nodes_n -> numero dei vertici
    # - iterations_number -> numero delle transizioni sulla catena di Markov
    # - acyclic -> true se si desidera un grafo aciclico
    # - pbar -> true se si desidera una barra di avanzamenti
    # - files -> specifica se salvare su più files la rappresentazione grafica di ogni grafo distinto generato
    # - freq_plot -> specifica il nome del file che conterrà il grafico delle frequenze
    params = { :acyclic => true, :pbar => true, :files => false, :freq_plot => 'freq_plot' }.merge(params)
    # parametri di default
    acyclic   = params[:acyclic]
    pbar      = params[:pbar]
    files     = params[:files]
    freq_plot = params[:freq_plot]

    if pbar
      # inizializza la barra di avanzamento
      require 'facets/progressbar'
      sampling_pbar = Console::ProgressBar.new("Graphs gen", graphs_n)
    end

    if files
      # inizializza la cartella "img"
      if Dir.entries(Dir.getwd).member?("img")
	Dir.foreach("img") { |f| File.delete("img/#{f}") if File.file?("img/#{f}") } 
      else
	Dir.mkdir("img")
      end
    end

    # inizializza l'hash contenente i grafi distinti e il loro rispettivo contatore
    grafi = {}
    # inizializza l'hash contenente tutti i grafi generati
    grafi_campionati = []
    # ciclo che genera i grafi
    1.upto(graphs_n) do
        g = RGL::RandomDAG.new(nodes_n, transitions_n, 'acyclic' => acyclic, 'pbar' => false)
	# rappresenta in una stringa la struttura del grafo
        stringa_grafo = g.to_s
	# aggiungi il grafo all'elenco dei grafi
	grafi_campionati << stringa_grafo
	# inserisci il grafo tra i grafi distinti, se non è già presente
        if !grafi.has_key?(stringa_grafo)
            grafi[stringa_grafo] = 1
	    if files == true
	      i = grafi.length
	      # stampa la rappresentazione del grafo su file
	      g.write_to_graphic_file('svg',"img/graph_#{i}")
	    end
        else
            occorrenze = grafi[stringa_grafo]
            grafi[stringa_grafo] = occorrenze + 1
        end #if
	sampling_pbar.inc if pbar
    end # upto do

    sampling_pbar.finish if pbar

  if freq_plot
    # stampa il grafico delle frequenze dei grafi distinti
    Gnuplot.open do |gp|
      Gnuplot::Plot.new( gp ) do |plot|
      
	plot.term "svg"
	plot.output "#{freq_plot}.svg"

	plot.title  "DAG casuali connessi con distribuzione uniforme"
	plot.ylabel "frequenze"
	plot.xlabel "grafi distinti"
    
	y = grafi.values
	x = (1..y.length).to_a
      
	margine = y.max - y.min
	y_min = y.min - margine > 0 ? y.min - margine : 0
	y_max = y.max + margine
	plot.yrange "[#{y_min}:#{y_max}]"
	#plot.yrange "[0:700]"

	plot.data << Gnuplot::DataSet.new( [x, y] ) do |ds|
	  ds.with = "dots"
	end # do
      end # do
    end # do
  end #if

  varianza_camp = 0
  # calcola la media campionaria 
  media_camp = graphs_n.to_f/grafi.values.size
  # calcola la varianza campionaria 
  grafi.values.each { |x| varianza_camp += (x-(media_camp))**2 }
  varianza_camp = varianza_camp/(graphs_n-1)
  puts "Numero di grafi distinti: #{grafi.values.size}\n"
  puts "Media campionaria: #{media_camp}\n"
  puts "Varianza campionaria: #{varianza_camp}\n"

  #grafi.values
  grafi_campionati
end # def test

# implementa il test non parametrico di Siegel tra campioni
# estratti dopo un numero di transizioni pari a transitions_n_A e transitions_n_B
def siegel_test(graphs_n, nodes_n, transitions_n_A, transitions_n_B)

  # genera i grafi del campione A
  campioni_A = test(graphs_n,nodes_n,transitions_n_A, :freq_plot => false)
 
  # genera i grafi del campione B
  campioni_B = test(graphs_n,nodes_n,transitions_n_B, :freq_plot => false)
  
  puts distribution_distance(a,b)
end # def

# siegel_test_n(100000,4,[100,200,300,400,1000])
def siegel_test_n(graphs_n, nodes_n, transitions_array)
  campioni = Hash.new
  transitions_array.each do |t|
    campioni[t] = test(graphs_n,nodes_n,t, :freq_plot => false)
  end
  transitions_array.each do |t|
    if t != transitions_array.last 
      next_t = transitions_array[transitions_array.index(t)+1]
      puts "Distanza tra #{t} e #{next_t}: #{distribution_distance(campioni[t],campioni[next_t])}" 
    end # if
  end # each
  transitions_array.each do |t|
    if t != transitions_array.last 
      puts "Distanza tra #{t} e #{transitions_array.last}: #{distribution_distance(campioni[t],campioni[transitions_array.last])}" 
    end # if
  end # each
end # def

def distribution_distance(campioni_A,campioni_B)

  a = []
  # etichetta i grafi con il campione di provenienza e li inserisce in un array di hashes {grafo => campione di provenienza}
  campioni_A.each do |g| 
    a << {g => 'A'}
  end

  b = []
  # etichetta i grafi con il campione di provenienza e li inserisce in un array di hashes {grafo => campione di provenienza}
  campioni_B.each do |g|
    b << {g => 'B'}
  end

  # unisce i campioni
  campioni = a + b
  # ordina gli elementi (hash) dell'array secondo la chiave 
  campioni.sort! { |a,b| a.keys[0] <=> b.keys[0] }

  wA = 0
  wB = 0
  # incrementa wA se il primo elemento dell'array appartiene al campione A
  if campioni[0].values[0] == 'A': wA +=1
    # altrimenti incrementa B
    else wB += 1
  end
  # cancella dall'array il primo elemento
  campioni.delete_at(0)
  # il rango viene impostato a 2
  i = 2
  # finché l'array non è vuoto
  while campioni.empty? == false do
	2.times do 
	  # estrai l'ultimo elemento dall'array ed incrementa wA o wB del rango a seconda del campione di appartenenza del dato estratto
	  if campioni.pop.values[0] == 'A': wA +=i
	  else wB += i
	  end
	  # interrompi il ciclo se l'array è vuoto
	  break if campioni.empty?
	  i +=1
	end
	 2.times do
	  # estrai il primo elemento dall'array ed incrementa wA o wB del rango a seconda del campione di appartenenza del dato estratto
	  if campioni[0].values[0] == 'A': wA +=i
	  else wB += i
	  end
	  campioni.delete_at(0)
	  # interrompi il ciclo se l'array è vuoto
	  break if campioni.empty?
	  i += 1
	end
  end # while
  puts "wA: #{wA}"
  puts "wB: #{wB}"
  (wA - wB).abs
end # def

# implementa il test non parametrico di Wilcoxon tra campioni
# estratti dopo un numero di transizioni pari a transitions_n_A e transitions_n_B
def wilcoxon_test(graphs_n, nodes_n, transitions_n_A, transitions_n_B)

  require 'rsruby'

  # genera i grafi del campione A
  campione_A = test(graphs_n,nodes_n,transitions_n_A, :freq_plot => false)
 
  # genera i grafi del campione B
  campione_B = test(graphs_n,nodes_n,transitions_n_B, :freq_plot => false)
  
  p_value(campione_A,campione_B)
end # def

def p_value(campione_A,campione_B)

  a = []
  # etichetta i grafi con il campione di provenienza e li inserisce in un array di hashes {grafo => campione di provenienza}
  campione_A.each do |g| 
    a << {g => 'A'}
  end

  b = []
  # etichetta i grafi con il campione di provenienza e li inserisce in un array di hashes {grafo => campione di provenienza}
  campione_B.each do |g|
    b << {g => 'B'}
  end

  # unisce i campioni
  campioni = a + b
  # ordina gli elementi (hash) dell'array secondo la chiave 
  campioni.sort! { |a,b| a.keys[0] <=> b.keys[0] }

  wA = []
  wB = []

  i = 0
  campioni.each do |x| 
    i += 1
    if x.values[0] == 'A' 
      wA << i
    else
      wB << i
    end
  end

  #puts "wA: #{wA}"
  #puts "wB: #{wB}"
  #(wA - wB).abs
  require 'rsruby'
  r = RSRuby.instance
  s = r.wilcox_test(wA,wB)
  s['p.value']
end # def

def wilcoxon_test_n(graphs_n, nodes_n, transitions_array)
  campioni = Hash.new
  transitions_array.each do |t|
    campioni[t] = test(graphs_n,nodes_n,t, :freq_plot => false)
  end
  transitions_array.each do |t|
    if t != transitions_array.last 
      next_t = transitions_array[transitions_array.index(t)+1]
      puts "p-value tra #{t} e #{next_t}: #{p_value(campioni[t],campioni[next_t])}" 
    end # if
  end # each
  transitions_array.each do |t|
    if t != transitions_array.last 
      puts "p-value tra #{t} e #{transitions_array.last}: #{p_value(campioni[t],campioni[transitions_array.last])}" 
    end # if
  end # each
end # def