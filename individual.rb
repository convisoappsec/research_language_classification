require './type.rb'

PPOOL_DIR = './ppool'
SAMPLE_DIR = './sample'
THREAD_LIMIT = 8


class Individual
  attr_reader :iid
  attr_accessor :fit
  def initialize(dict = {}, iid = 0)
    @dict = dict
    @fit = nil
    
    @reader, @writer = IO.pipe
  end
  
  def fit
    if @fit.nil? 
      @fit = @reader.gets.strip.to_f
    end
    return @fit
  end
  
  def crossover (other = nil)
    
  end
  
  def mutate!
  end
  
  def evaluate
    total = 0
    errors = 0
    
    Dir.glob(File.join(SAMPLE_DIR, '*')).each do |f|
      extension = "." + f.split('.').last.strip
      next if extension == '.h'
      reality = @dict.keys.select {|k| @dict[k][:extension].include?(extension)}.to_a.first
      
      while (Thread.list.select{|t| t.status}.size == THREAD_LIMIT)
        sleep(1)
      end
      
      t = Thread.new {
        answer = __analyse_file(f)
        total += 1
        if reality != answer
          errors += 1 
        end
      }
    end
    
    total_error = errors.to_f * 100.00 / total.to_f
    
    @writer.puts "#{total_error}"
    return total_error
  end
  
  def crossover!(i = nil)
    
  end
  
  private
  def __analyse_file(file = nil)
    begin
      return Profile::Type::classify!(file, false)
    rescue
      return ''
    end
  end
end
