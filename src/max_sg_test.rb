load 'random_graph.rb'

#range1 = (1..9).to_a
#range = range1 + range1.collect {|x| x*10 } + [100] - [1]
## range = [2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
#multiplier = 1
#range = [200,300]

while 1 do
	range.each do |n|
		#n = x * multiplier
		puts "\n\n==> n = #{n.to_int} <==\n"
		g = RGL::RandomDAG.new(n.to_int,(n**2).to_int, :pbar => true, :acyclic => true)
		sg = SG_solver.new(g, :pbar => true)
		sg.stats(g)
		#puts "max_sg_value: #{sg.max_sg_value}\n"
		File.open(n.to_s,"a") { |file| file << "#{sg.max_sg_value}\n" }
		File.open("#{n}_acyclic_ude","a") { |file| file << "#{sg.ude_counter['u']},#{sg.ude_counter['d']},#{sg.ude_counter['e']}\n" }
	end # each do
end # while
