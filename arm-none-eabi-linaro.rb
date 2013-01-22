require 'formula'

class LinaroNewlib < Formula
  homepage 'http://www.sourceware.org/newlib/'
  url 'ftp://sources.redhat.com/pub/newlib/newlib-1.20.0.tar.gz'
  mirror 'http://mirrors.kernel.org/sources.redhat.com/newlib/newlib-1.20.0.tar.gz'
  sha1 '65e7bdbeda0cbbf99c8160df573fd04d1cbe00d1'
end

class LinaroGdb < Formula
  homepage 'https://launchpad.net/gdb-linaro'
  url 'https://launchpad.net/gdb-linaro/7.5/7.5-2012.12-1/+download/gdb-linaro-7.5-2012.12-1.tar.bz2'
  md5 '016cf2c5ed06adf7c601e3301a14e370'
end

class ArmNoneEabiLinaro < Formula
  homepage 'https://launchpad.net/gcc-linaro'
  url 'https://launchpad.net/gcc-linaro/4.7/4.7-2013.01/+download/gcc-linaro-4.7-2013.01.tar.bz2'
  md5 '823516979de64df3ab6351c5ad3a9773'
  version '2013.01'
  
  depends_on 'gmp'
  depends_on 'mpfr'
  depends_on 'libmpc'
  depends_on 'ppl'
  depends_on 'cloog'
  depends_on 'binutils'

  def install
    # Define the target triple
    target = "arm-none-eabi"
    # Undefine LD, gcc expects that this will not be set
    ENV.delete 'LD'

    # Compiling a cross compiler precludes the use of the normal bootstrap
    # compiler process so we need to use GCC to compile the toolchain. Luckily
    # LLVM-GCC works.
    ENV.llvm

    # Halfway through the build process the compiler switches to an internal
    # version of gcc that does not understand Apple specific options.
    ENV.cc_flag_vars.each do |var|
      ENV.delete var
    end
    ENV.delete 'CPPFLAGS'
    ENV.delete 'LDFLAGS'
    unless HOMEBREW_PREFIX.to_s == '/usr/local'
      ENV['CPPFLAGS'] = "-I#{HOMEBREW_PREFIX}/include"
      ENV['LDFLAGS'] = "-L#{HOMEBREW_PREFIX}/lib"
    end
    #ENV.set_cflags "-Os -w -pipe"

    # We need to use our toolchain during the build process, prepend it to PATH
    ENV.prepend 'PATH', bin, ':'

    # Build newlib alongside gcc for simplicity
    source_dir = Pathname.new Dir.pwd
    [LinaroGdb, LinaroNewlib].each do |formula|
      formula.new.brew do |brew|
        system "rsync", "-av", "--ignore-existing", Dir.pwd+'/', source_dir
      end
    end

    cross_prefix = prefix + target
    args = [
      "--prefix=#{cross_prefix}",
      "--bindir=#{bin}",
      "--datarootdir=#{share}",
      #"--with-sysroot=#{prefix}",
      "--program-prefix=#{target}-linaro-",
      "--target=#{target}",
      "--disable-nls",
      "--enable-interwork",
      "--enable-multilib",
      "--enable-languages=c,c++",
      "--with-newlib",
      "--disable-shared",
      "--disable-threads",
      "--disable-libssp",
      "--disable-libstdcxx-pch",
      "--disable-libmudflap",
      "--disable-libgomp",
      #"--enable-poison-system-directories",
      "--with-python=no",
    ]
    # Specify the exact directory where the dependent libs are
    ['gmp', 'mpfr', 'ppl', 'cloog'].each do |dep|
      args << "--with-#{dep}=#{(Formula.factory dep).prefix}"
    end
    args << "--enable-cloog-backend=isl"
    args << "--with-mpc=#{(Formula.factory 'libmpc').prefix}"

    # Some (most?) of these packages prefer to be built in a seperate directory
    mkdir 'build' do
      system "../configure", *args
      system "make"
      # Install must be sequential
      ENV.j1
      system "make", "install"
    end
  end
end
