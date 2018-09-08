load 'random_graph.rb'

# calcola la funzione di Sprague-Grundy sul grafo in ingresso
#
class SG_solver
   
  attr_reader :ude_counter

  # genera un grafo casuale
  # parametri:
  # - pbar -> true se si desidera una barra di avanzamento
  # - file -> specifica se salvare su file una rappresentazione grafica del grafo
  def initialize(g, params = {})

    require 'set'
    
    params = { :pbar => false, :file => '', :color => true, :circo => false }.merge(params)
    @pbar  = params[:pbar]
    file   = params[:file]
    color  = params[:color]
    circo  = params[:circo]

    if @pbar
      require 'facets/progressbar'
      @labeling_pbar = Console::ProgressBar.new("Labeled nodes", g.num_vertices)
    end

    # initializza etichette e contatori
    @i = 0
    @m = 0
    @l = Hash.new
    @c = Hash.new
    @ude_counter = Hash.new
    @unlabeled_v = g.vertices.to_set

    if g.cyclic?
      # applica l'algoritmo generalizzato
      until @unlabeled_v.empty?
	label_and_counter(g)
	inf_label(g)
	@i += 1
      end
    else
      # applica l'algoritmo lineare
      succ = Hash.new
      g.vertices.each do |v|
	successivi = Array.new
	g.adjacent_vertices(v).each do |sv| 
	  successivi << sv
	end # each
	succ[v] = successivi
      end # each
      coda = Array.new
      g.vertices.each do |v| 
	if g.adjacent_vertices(v) == []
	  @l[v] = 0
	  @labeling_pbar.inc if @pbar
	  coda.push(v) 
	end # if
      end # each
      while coda != [] do
	x = coda[0]
	coda.delete(x)
	g.prev_vertices(x).each do |v|
	  succ[v].delete(x)
	  if succ[v] == []
	    @l[v] = mes(v,g)
	    coda.push(v)
	    @labeling_pbar.inc if @pbar
	  end # if
	end # each
      end # while
    end # if
    @labeling_pbar.finish if @pbar
    count_ude(g)

    write_to_graphic_file(g, fmt='png', dotfile=file, color, circo) if (file != '' and file.is_a?(String))
  end # def

  # calcola il minimo intero escluso del vertic v
  def mes(v,g)
    l_succ = Set.new
    g.adjacent_vertices(v).each { |sv| l_succ << @l[sv] }
    i = 0
    i += 1 until l_succ.member?(i) == false
    @l[v] = i 
  end

  # imposta etichette e contatori
  def label_and_counter(g)
    ### il ciclo va ripetuto finché in @unlabeled_v non ci sono vertici che soddisfano le condizioni c1 e c2
    continue = true
    until continue == false
      continue = false
      @unlabeled_v.each do |v| 
	if (c1?(g,v) and c2?(g,v)) 
	  set_label(v,@i)
	  @c[v] = @m
	  @m += 1
	  continue = true
	end # if
      end # do
    end # until
  end # def

  # etichetta con il valore infinito
  def inf_label(g)
    @unlabeled_v.each do |u| 
      no_follower_labeled_i = true
      g.adjacent_vertices(u).each do |v|
	no_follower_labeled_i = false if @l[v] == @i.to_s
      end # do
      set_label(u,'inf') if no_follower_labeled_i
    end # do
  end # def

  # imposta l'etichetta l sul vertice v
  def set_label(v,l)
    @l[v] = l.to_s 
    @unlabeled_v.delete(v)
    @labeling_pbar.inc if @pbar
  end # def

  # soddisfa la condizione C1?
  def c1?(g,u)
    g.adjacent_vertices(u).each do |v| 
      if @l[v] == @i.to_s
	return false
      end # if
    end # do
    return true
  end # def

  # soddisfa la condizione C2?
  def c2?(g,u)
    ok = false
    g.adjacent_vertices(u).each do |v| 
      if (@l[v] == nil or @l[v] == 'inf')
	g.adjacent_vertices(v).each do |z|
	  if @l[z] == @i.to_s
	    ok = true
	    break
	  end # if
	  ok = false
	end # do
	if ok == false
	  return false
	end # if
      end # if
    end # do
    return true
  end # def

  def write_to_graphic_file (g, fmt='png', dotfile='sg_graph', color = true, circo = false)

      position = {1 => "100,200", 
		  2 => "200,200", 
		  3 => "200,100", 
		  4 => "100,100"}
      src = dotfile + ".dot"
      dot = dotfile + "." + fmt       
      v_colors = {'U' => 'red', 'D' => 'yellow', 'E' => 'green'}
      e_colors = {'U' => 'green', 'D' => 'yellow', 'E' => 'red'}
      v_shape  = {'U' => "triangle \n        width = 1 \n        height = 1 \n", 
		  'D' => "circle \n        width = 1 \n        height = 1 \n", 
		  'E' => "box \n        width = 1 \n        height = 0.6 \n"}
      e_style  = {'U' => 'solid', 'D' => 'dashed', 'E' => 'dotted'}

      File.open(src, 'w') do |f|
	f << "digraph #{self.class.name.gsub(/:/,'_').to_s} {\n"
	f << "    graph [ bgcolor = black ] \n" if color
	f << "    node [ style = filled ] \n\n"  if color
	g.each_vertex do |v|
	  ude_label = ude(v,g)
	  name = v.to_s + "_#{@l[v]}"
	  f << "    v#{name} [\n"
	  #f << "        fontsize = 8\n"
	  #f << "        label = v#{name}\n"
	  f << "        color = #{v_colors[ude_label]}\n" if color
	  f << "        shape = #{v_shape[ude_label]}\n" if !color
	  f << "        pos = \"#{position[v]}\"\n" if g.num_vertices < 5
	  f << "    ]\n\n"
	end # do
	g.each_edge do |u,v|
	  #u_ude_label = ude(u,g)
	  v_ude_label = ude(v,g)
	  f << "    v#{u.to_s}_#{@l[u]} -> v#{v.to_s}_#{@l[v]}"
	  f << " [ color = #{e_colors[v_ude_label]} ]" if color
	  f << " [ style = #{e_style[v_ude_label]} ]" if !color
	  f << " \n\n"
	end # do
   	f << "}"
      end
      if g.num_vertices < 5
	system( "neato -s -n -T#{fmt} #{src} -o #{dot}" ) 
      elsif circo 
	system( "circo -T#{fmt} #{src} -o #{dot}" )
      else
	system( "dot -T#{fmt} #{src} -o #{dot}" )  
      end # if
      dot
    end # def

    # restituisce il valore massimo della funzione di Sprague-Grundy
    def max_sg_value
      @l.values.max
    end # def

    # restituisce il numero di vertici con etichetta 0
    def zeros
      counter = 0
      @l.each_value do |v|
	counter +=1 if v == '0'
      end # do
      counter
    end # def
  
    # restituisce il numero di vertici con etichetta intera diversa da 0
    def positives
      @l.size - zeros - infs
    end # def

    # restituisce il numero di vertici con etichetta infinito
    def infs
      counter = 0
      @l.each_value do |v|
	counter +=1 if v == 'inf'
      end # do
      counter
    end # def

    # conta il numero di vertici U, D, E
    def count_ude(g)
      @ude_counter['u'] = zeros
      zeros_v = []
      @l.each do |k,v|
    	zeros_v << k if v == 'inf'
      end # do
      d_v_counter = 0
      zeros_v.each do |zv|
	no_follower_labeled_zero = true
    	g.adjacent_vertices(zv).each do |v|
    		no_follower_labeled_zero = false if @l[v] == '0'
      	end # do
      	d_v_counter +=1 if no_follower_labeled_zero
      end # do
      @ude_counter['d'] = d_v_counter
      @ude_counter['e'] = g.num_vertices - @ude_counter['u'] - @ude_counter['d']
    end # def

    # stampa a video le statistiche sul numero di U, D, E e il valore massimo della funzione di Sprague-Grundy
    def stats(g)
      puts "Numero di stati U: #{@ude_counter['u']}"
      puts "Numero di stati D: #{@ude_counter['d']}"
      puts "Numero di stati E: #{@ude_counter['e']}"
      puts "---------------------"
      puts "Valore massimo della funzione di SG: #{max_sg_value}"
    end # def

    # controlla se il vertice v è di tipo U, D o E
    def ude(v,g)
      return 'U' if @l[v] == '0'
      no_follower_labeled_zero = true
      g.adjacent_vertices(v).each do |av|
	no_follower_labeled_zero = false if @l[av] == '0'
      end # do
      return 'D' if no_follower_labeled_zero
      return 'E'
    end # def

end # class