require 'ant'
require 'rake/testtask'

RHINO='/Developer/rhino1_7R2/js.jar'

def js(script)
  ant.java :fork => true, :jar => RHINO, :failonerror => true, :dir=>Dir.pwd do
    arg :value => script
  end
end

task :default => :test

directory 'dist'
directory 'build/test'
directory 'build/jmeta'

task :clean do
  ant.delete :quiet => true, :dir => 'build'
  ant.delete :quiet => true, :dir => 'dist'
end

file "build/boot/jmetaparser.js" => Dir.glob('boot/jmeta*.txt') + ['build/jmeta'] do
  cp_r 'boot', 'build/'
  chdir('build/boot') do
    js('boot.js')
  end
end

rule(%r(build/jmeta/.+\.java$) => [
    "build/boot/jmetaparser.js",
    proc {|n| n.sub(/\.java$/, '.jmeta').sub(%r(^build/jmeta), 'boot')}]) do |n|
  n.name =~ %r(/(JMeta.+)\.java)
  name = $1
  cp "boot/#{name}.jmeta", 'build/boot'
  chdir 'build/boot' do
    js("boot-#{name.downcase}.js")
  end
end

file 'build/jmeta/JMetaParser.class' => ["build/jmeta/JMetaParser.java",
                                         "build/jmeta/JMetaCompiler.java"] +
                                        Dir.glob('jmeta/*.java') do
  ant.javac :srcDir=>'jmeta', :destDir => 'build', :debug=>true
  ant.javac :srcDir=>'build/jmeta', :destDir => 'build', :debug=>true
end

task :depend do
  ant.depend :srcDir => '.', :destDir => 'build', :cache => 'build/depcache'
end

task :compile => [:depend, 'build/jmeta/JMetaParser.class']

file 'dist/jmeta.jar' => ['build/jmeta/JMetaParser.class', 'build/jmeta/JMetaCompiler.class', 'dist'] do
  ant.jar :destfile=>'dist/jmeta.jar', :basedir=>'build', :includes=>'jmeta/*.class' do
    manifest do
      attribute :name=>"Main-Class", :value=>"jmeta.JMetaParser"
    end
  end
  ant.jar :destfile=>'dist/jmeta-runtime.jar', :basedir=>'build',
      :includes=>'jmeta/*.class', :excludes=>'jmeta/JMeta*.class,jmeta/Utils.class'
end

task :jar => [:compile, 'dist/jmeta.jar']

namespace :test do
  task :compile => [:jar] do
    ant.javac :srcDir => 'build/test', :classpath=>'dist/jmeta-runtime.jar', :debug=>true
  end
  task :calc => :'test:compile' do
    ant.java :fork=> true, :outputproperty=>'test.output',
             :classpath=>'dist/jmeta-runtime.jar:build/test',
             :classname=>'Calculator', :failonerror=>true  do
      arg :value=>"4 * 3 - 2"
    end
    if ant.properties['test.output'].to_s.strip == '10'
      puts "Calculator passed"
    else
      puts "Expected calculator result 10, got #{ant.properties['test.output']}"
      exit(1)
    end
  end
  Rake::TestTask.new :mirah do |t|
    t.libs << 'build/test'
    t.test_files = FileList['test/*.rb']
  end
end

Dir.glob('test/*.jmeta').each do |f|
  name = File.basename(f, '.jmeta')
  task(:'test:compile').enhance ["build/test/#{name}.java"]
  file "build/test/#{name}.java" => [f, 'dist/jmeta.jar', 'build/test'] do
    cp "test/#{name}.jmeta", "build/test/"
    ant.java :fork => true, :jar => 'dist/jmeta.jar', :failonerror => true do
      arg :value => "build/test/#{name}"
    end
  end
end

task :test => [:'test:calc', :'test:mirah']
