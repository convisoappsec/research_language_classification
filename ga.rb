require './individual.rb'
require './macros.rb'
require 'pry'
require 'yaml'
require 'digest/sha1'

population_size = 6
hall_of_fame_size = 2
iterations = 200
paralelism = 3
already_tested = []
randomize_threshold = 3
counter = {:total_tests => 0, :repeated_tests => 0, :envolve_period => 0}


File.delete('fitness.txt') if File.exists?('fitness.txt')
File.delete('best_solution.txt') if File.exists?('best_solution.txt')

fitness_fd = File.open('fitness.txt', 'a')
best_solution_fd = File.open('best_solution.txt', 'a')


def __calculate_dict_hash(individual = nil)
  str = individual.dict.keys.collect {|lang| individual.dict[lang].sort.join(',') }.sort.join('|')
  return Digest::SHA1.hexdigest(str)
end


def __rdn_dict(list = nil)
  new_dict = {}

  list.keys.each do |k|
    keyword_size = list[k][:keyword].size
    min = (keyword_size * 0.4).to_i
    new_dict[k] = {
      :keyword => list[k][:keyword].shuffle[0..(min+rand(keyword_size-min))],
      :extension => list[k][:extension]
    }
  end
  return new_dict
end

population = (1..population_size).collect { |x|
  Individual.new(__rdn_dict(LANGUAGES_KEYWORDS))
}

hall_of_fame = population[0..hall_of_fame_size]

puts "[+] Creating a population of #{population.size} individuals"

process_pool = []
(1..iterations).each do |iteration|
  i = 1
  puts "[+] Starting iteration [#{iteration}]"
  
  already_tested += population.collect { |i| __calculate_dict_hash(i)}
  already_tested.uniq!
  
  while i <= population_size  do

    # Calculates number of active processes
    process_pool = process_pool.select do |pid| 
      begin 
        Process.getpgid(pid)
        true
      rescue
        false
      end # begin
    end # do
    
    # If there is space inside the process pool just trigger one more process
    if process_pool.size < paralelism
#       puts "[+] Process pool with size #{process_pool.size}"
#       puts "[+] Adding a new process to the process pool"
      pid = fork {
        population[i-1].evaluate
      }
      Process.detach(pid)
      process_pool << pid
      i += 1
    else
      sleep 1
    end # if
  end # while
    

  # Checking out all the results after processing all population
  puts "[+] Collecting results for this population"
  population.sort!{|a,b| a.fit <=> b.fit}
  puts "[+] Fittest individual: #{population.first.fit}"
  puts "[+] Less fittest individual: #{population.last.fit}"
  
  
  # Storing the "hall_of_fame_size" best solution
  last_fittest = hall_of_fame.first.fit
  hall_of_fame = (hall_of_fame + population[0..hall_of_fame_size]).sort {|a,b| a.fit <=> b.fit}[0..hall_of_fame_size].collect {|i| i.clone}
  new_fittest = hall_of_fame.first.fit
  
  if last_fittest == new_fittest
    counter[:envolve_period] += 1
  end
  
  puts "[+] Global Best #{hall_of_fame.first.fit}"
  
  fitness_fd.puts(hall_of_fame.first.fit)
  fitness_fd.flush
  best_solution_fd.puts(hall_of_fame.first.dict.to_yaml.inspect)
  best_solution_fd.flush
  

  population.sort!{|a,b| a.fit <=> b.fit}
  population.each do |i| 
    i.crossover!(hall_of_fame.sample)
    counter[:total_tests] += 1
    while(already_tested.include?(__calculate_dict_hash(i)))
      counter[:repeated_tests] += 1
      i.crossover!(hall_of_fame.sample) 
    end

  end
  
  if counter[:envolve_period] == randomize_threshold
    puts "[+] Randomizing half of the population ..."
    population[(population_size/2)..-1].each { |i|
      i.dict = __rdn_dict(LANGUAGES_KEYWORDS)
    }
    counter[:envolve_period] = 0
  end

  
  puts counter.inspect
  puts "\n"
end

fitness_fd.close
best_solution_fd.close
