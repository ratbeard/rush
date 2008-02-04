module Rush
	class Dir < Entry
		def dir?
			true
		end

		def full_path
			"#{super}/"
		end

		def contents
			find_by_regexp(//)
		end

		def files
			contents.select { |entry| !entry.dir? }
		end

		def dirs
			contents.select { |entry| entry.dir? }
		end

		def [](key)
			if key.kind_of? Regexp
				find_by_regexp(key)
			else
				key = key.to_s
				if key == '**'
					files_flattened
				elsif key.slice(0, 3) == '**/'
					find_by_doubleglob(key)
				elsif key.match(/\*/)
					find_by_glob(key)
				else
					find_by_name(key)
				end
			end
		end

		def find_by_name(name)
			Rush::Entry.factory("#{full_path}/#{name}", box)
		end

		def find_by_glob(glob)
			find_by_regexp(self.class.glob_to_regexp(glob))
		end

		def find_by_regexp(pattern)
			connection.index(full_path, pattern.source).map do |fname|
				Rush::Entry.factory("#{full_path}#{fname}", box)
			end
		end

		def find_tree_by_regexp(pattern)
			connection.index_tree(full_path, pattern.source).map do |fname|
				Rush::Entry.factory("#{full_path}#{fname}", box)
			end
		end

		def self.glob_to_regexp(glob)
			Regexp.new("^" + glob.gsub(/\./, '\\.').gsub(/\*/, '.*') + "$")
		end

		def entries_tree
			connection.index_tree(full_path).map do |fname|
				Rush::Entry.factory("#{full_path}#{fname}", box)
			end
		end

		def files_flattened
			entries_tree.select { |e| !e.dir? }
		end

		def dirs_flattened
			entries_tree.select { |e| e.dir? }
		end

		def find_by_doubleglob(doubleglob)
			glob = doubleglob.gsub(/^\*\*\//, '')

			find_tree_by_regexp(self.class.glob_to_regexp(glob))
		end

		def make_entries(filenames)
			filenames.map do |fname|
				Rush::Entry.factory("#{full_path}/#{fname}")
			end
		end

		def create_file(name)
			file = self[name].create
			file.write('')
			file
		end

		def create_dir(name)
			name += '/' unless name.tail(1) == '/'
			self[name].create
		end

		def create
			connection.create_dir(full_path)
			self
		end

		def size
			connection.size(full_path)
		end

		def nonhidden_dirs
			dirs.select do |dir|
				!dir.hidden?
			end
		end

		def nonhidden_files
			files.select do |file|
				!file.hidden?
			end
		end

		def ls
			out = [ "#{self}" ]
			nonhidden_dirs.each do |dir|
				out << "  #{dir.name}+"
			end
			nonhidden_files.each do |file|
				out << "  #{file.name}"
			end
			out.join("\n")
		end

		def rake(*args)
			system "cd #{full_path}; rake #{args.join(' ')}"
		end

		def git(*args)
			system "cd #{full_path}; git #{args.join(' ')}"
		end

		include Rush::Commands

		def entries
			contents
		end
	end
end
