#load 'random_graph.rb'
load 'sprague_grundy.rb'

#n = 1
#range1 = (1..9).to_a
#range = range1 + range1.collect {|x| x*10 } + [100] - [1,2]
## range = [2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100]

range = (11..19).to_a

while 1 do
	range.each do |n| 
		i = 0
                puts "\n\n==> n = #{(n).to_int} <==\n"
                g = RGL::RandomDAG.new(n,n**2, :pbar => true, :acyclic => false)
                sg = SG_solver.new(g,:pbar => false)
                while sg.ude_counter['u'] == 0 or g.acyclic? do
                         i += 1
                         sg = SG_solver.new(g = g.next_transition,:pbar => false)
                         puts i if i.modulo(500) == 0
                end # while
                puts "Numero di transizioni extra necessarie: #{i}\n"
                puts "ERRORE: g aciclico" if g.acyclic?
                sg.stats(g)
                puts '==============='
                #File.open("#{n}_tries_cyclic_ude","a") { |file| file << "#{i}\n" }
                File.open("#{n}_cyclic_ude","a") { |file| file << "#{sg.ude_counter['u']},#{sg.ude_counter['d']},#{sg.ude_counter['e']}\n" }
	end # each
end # while

# and sg.ude_counter['d'] != 0 and sg.ude_counter['e'] != 0
#sg.write_to_graphic_file(g,fmt='png', dotfile='sg_graph_color', color = true)
#sg.write_to_graphic_file(g,fmt='png', dotfile='sg_graph_bn', color = false)
