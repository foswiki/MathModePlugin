# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006-2009 Michael Daum http://michaeldaumconsulting.com
# Copyright (C) 2002 Graeme Lufkin, gwl@u.washington.edu
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html
#
###############################################################################

package Foswiki::Plugins::MathModePlugin::Core;

use strict;
use Digest::MD5 qw( md5_hex );
use File::Copy qw( move );
use File::Temp;
use FindBin;
use Foswiki::Sandbox;

use constant DEBUG => 0; # toggle me

###############################################################################
# static
sub writeDebug {
  #&Foswiki::Func::writeDebug('- MathModePlugin - '.$_[0]) if DEBUG;
  print STDERR '- MathModePlugin - '.$_[0]."\n" if DEBUG;
}

###############################################################################
sub new {
  my $class = shift;

  my $this = {
    hashedMathStrings => {}, 
      # contains the math strings, indexed by their hash code

    fgColors => {},
      # contains the foreground color of a math string

    bgColor => {},
      # contains the background color for all formulas

    sizes => {},
      # font size of a math string, can be; can be
      # tiny, scriptsize, footnotesize, small, normalsize, large, Large, LARGE,
      # huge or Huge

    hashCodeLength => $Foswiki::cfg{MathModePlugin}{HashCodeLength} || 32,
      # length of the hash code. If you switch to a different
      # hash function, you will likely have to change this

    imagePrefix => $Foswiki::cfg{MathModePlugin}{ImagePrefix} || '_MathModePlugin_',
      # string to be prepended to any auto-generated image

    latex2Img => $Foswiki::cfg{MathModePlugin}{Latex2Img},
      # the command to convert latex to a png or gif

    scaleFactor => $Foswiki::cfg{MathModePlugin}{ScaleFactor} || 1.2,
      # factor to scale images;
      # may be overridden by a LATEXSCALEFACTOR preference variable

    latexFGColor => $Foswiki::cfg{MathModePlugin}{LatexFGColor} || 'black',
      # default text color

    latexBGColor => $Foswiki::cfg{MathModePlugin}{LatexBGColor} || 'white',
      # default background color

    latexFontSize => $Foswiki::cfg{MathModePlugin}{LatexFontSize} || 'normalsize',
      # default text color

    latexPreamble => $Foswiki::cfg{MathModePlugin}{Preamble} || 
      '\usepackage{latexsym}',
      # latex preamble, e.g. to include additional packages; may be 
      # overridden by a LATEXPREAMBLE preference variable;
      # Example: \usepackage{mathptmx} to change the math font

    imageType => $Foswiki::cfg{MathModePlugin}{ImageType} || 'png',
      # extension of the image type;
      # may be overridden by a LATEXIMAGETYPE preference variable

    @_
  };

  return bless($this, $class);
}

###############################################################################
# delayed initialization
sub init {
  my ($this, $web, $topic) = @_;

  # prevent a doubled invokation
  return if $this->{isInitialized};
  $this->{isInitialized} = 1;

  # get preverences
  my $value = Foswiki::Func::getPreferencesValue('LATEXSCALEFACTOR');
  $this->{scaleFactor} = $value if $value;

  $value = Foswiki::Func::getPreferencesValue('LATEXIMAGETYPE');
  $this->{imageType} = $value if $value;
  $this->{imageType} = 'png' unless $this->{imageType} =~ /^(png|gif)$/i;

  $value = Foswiki::Func::getPreferencesValue('LATEXPREAMBLE');
  $this->{latexPreamble} = $value if $value;

  $value = Foswiki::Func::getPreferencesValue('LATEXBGCOLOR');
  $this->{latexBGColor} = $value if $value;

  $value = Foswiki::Func::getPreferencesValue('LATEXFGCOLOR');
  $this->{latexFGColor} = $value if $value;

  $value = Foswiki::Func::getPreferencesValue('LATEXFONTSIZE');
  $this->{latexFontSize} = $value if $value;

  # get the current cgi
  my $pathInfo = $ENV{'PATH_INFO'} || '';
  my $script = $ENV{'REQUEST_URI'} || '';
  if ($script =~ /^.*?\/([^\/]+)$pathInfo.*$/) {
    $script = $1;
  } else {
    $script = 'view';
  }
  $this->{cgiScript} = $script;

  # compute filenname length of an image
  $this->{imageFileNameLength} =
    $this->{hashCodeLength}+length($this->{imageType})+length($this->{imagePrefix})+1;

  # get refresh request
  my $query = Foswiki::Func::getCgiQuery();
  my $refresh = $query->param('refresh') || '';
  $this->{doRefresh} = ($refresh =~ /^(on|yes|1)$/)?1:0;

  # create the topic pubdir if it does not exist already
  my $pubDir = $Foswiki::cfg{PubDir};
  my $topicPubDir = $pubDir;
  foreach my $dir (split(/\//, "$web/$topic")) {
    $topicPubDir .= '/'.$dir;
    $topicPubDir = Foswiki::Sandbox::normalizeFileName($topicPubDir);
    unless (-d $topicPubDir) {
      mkdir $topicPubDir or die "can't create directory $topicPubDir";
    }
  }
  $this->{topicPubDir} = $topicPubDir;

  # default to supplied tools
  unless ($this->{latex2Img}) {
    # Build a list of paths that might be the tools directory
    # SMELL: There should be an API to provide the path to /tools
    my @possibleToolsDirs = ();
    if (exists $Foswiki::cfg{LocalesDir}) {
      # Assumes that /tools and /locale are in the same directory
      push @possibleToolsDirs, "$Foswiki::cfg{LocalesDir}/../tools";
    }
    if (defined $FindBin::Bin) {
      # Assumes that /tools and /bin are in the same directory
      # Assumes that $FindBin::Bin gives /bin
      #  - which might be wrong under mod_perl
      $FindBin::Bin =~ /(.*)/; #untaint
      push @possibleToolsDirs, "$1/../tools";
    }
    # Look in these directories to see if the default supplied tool is there
    my $defaultScriptName = 'MathModePlugin_latex2img';
    POSSIBLE_DIR: for my $possibleToolsDir (@possibleToolsDirs) {
      if (-e "$possibleToolsDir/$defaultScriptName" and
          -x "$possibleToolsDir/$defaultScriptName")
      {
        $this->{latex2Img} = "$possibleToolsDir/$defaultScriptName";
        last POSSIBLE_DIR;
      }
    }
  }

}

###############################################################################
# This function takes a string of math, computes its hash code, and returns a
# link to what will be the image representing this math.
sub handleMath {
  my ($this, $web, $topic, $text, $inlineFlag, $args) = @_;
  
  # store the string in a hash table, indexed by the MD5 hash
  $text =~ s/^\s+//go;
  $text =~ s/\s+$//go;

  # extract latex options
  $args ||= '';
  require Foswiki::Attrs;
  my $params = new Foswiki::Attrs($args);
  $this->{fgColors}{$text} = $params->{color} || $this->{latexFGColor};
  $this->{bgColor} = $params->{bgcolor} || $this->{latexBGColor};

  my $size = $params->{size} || '';
  $this->{sizes}{$text} = $size if $size;

  # TODO: add global settings to hash
  my $hashCode = md5_hex($text.$this->{fgColors}{$text}.$this->{bgColor}.$size);
  $this->{hashedMathStrings}{$hashCode} = $text;
  #writeDebug("hashing '$text' as $hashCode");

  # construct url path to image
  my $url = Foswiki::Func::getPubUrlPath().'/'.$web.'/'.$topic.
    '/'.$this->{imagePrefix}.$hashCode.'.'.$this->{imageType};

  # return a link to an attached image, which we will create later
  my $container = $inlineFlag?'span':'div';
  my $alt = entityEncode($text);
  my $result = '<img alt="'.$alt.'" class="mmpImage" src="'.$url.'" '.$args.' />';
  $result = "<$container class='mmpContainer' align='center'>".$result."<\/$container>"
    unless $inlineFlag == 2;

  return $result;
}

###############################################################################
# from Foswiki.pm
sub entityEncode {
  my ($text, $extra) = @_;
  $extra ||= '';

  $text =~
    s/([[\x01-\x1f"%&'*<=>@[_\|$extra])/'&#'.ord($1).';'/ge;

  return $text;
}

###############################################################################
sub postRenderingHandler {
  my ($this, $web, $topic) = @_;

  return unless keys %{$this->{hashedMathStrings}};

  # initialize this call
  $this->init($web, $topic);

  # check if there are any new images to render
  return unless $this->checkImages();

  # do it
  my $msg = $this->renderImages() || '';

  # append to text
  $_[3] .= $msg;
}

###############################################################################
# if this is a save script, then we will try to delete old files;
# existing files are checkd if they are still in use;
# returns the number of images to be re-rendered
sub checkImages {
  my $this = shift;

  # only delete during a save
  my $deleteFiles = ($this->{cgiScript} =~ /^save/ || $this->{doRefresh})?1:0;

  #writeDebug("deleteFiles=$deleteFiles, cgiScript=$this->{cgiScript}");

  # look for existing images, delete old ones
  opendir(DIR,$this->{topicPubDir}) or die "can't open directory $this->{topicPubDir}";
  my @files = grep(/$this->{imagePrefix}.*\.$this->{imageType}$/,readdir(DIR));
  foreach my $fileName (@files) {
    $fileName = Foswiki::Sandbox::normalizeFileName($fileName);
    #writeDebug( "found image: $fileName");

    # is the filename the same length as one of our images?
    next unless length($fileName) == $this->{imageFileNameLength};

    # is the filename composed of the same characters as ours?
    my $hashCode = $fileName;
    next unless $hashCode =~ /^$this->{imagePrefix}(.*)\.$this->{imageType}$/;
    $hashCode = $1;
    next unless length($hashCode) == $this->{hashCodeLength};

    # is the image still used in the document?
    if (exists($this->{hashedMathStrings}{$hashCode} ) ) {
      # the image is already there, we don't need to re-render;
      # refresh the cache only if we asked for it
      unless ($this->{doRefresh}) {
        #writeDebug("skipping $this->{hashedMathStrings}{$hashCode}");
        delete $this->{hashedMathStrings}{$hashCode};
        next;
      }
    }
    
    # maintenance
    next unless $deleteFiles;
    $fileName = $this->{topicPubDir}.'/'.$fileName;
    #writeDebug("deleting old image $fileName");
    unlink $fileName or die "can't delete file $fileName";
  }

  return scalar(keys %{$this->{hashedMathStrings}});
}

###############################################################################
sub renderImages {
  my $this = shift;

  # used for reporting errors
  my $msg;

  # create temporary storage
  my $tempDir = File::Temp::tempdir(CLEANUP =>1);
  my $tempFile = new File::Temp(DIR=>$tempDir);
  chdir $tempDir or die "can't change to temp dir $tempDir";

  # maps math strings' hash codes to the filename latex2html generates
  my %imageFile = ();

  # latex2html names its image img(n).png where (n) is an integer
  # we will rename these files, so need to know which math string gets with image
  my $imageNumber = 0;

  # create the latex file on the fly
  print $tempFile "\\documentclass[fleqn,12pt]{article}\n";
  print $tempFile <<'PREAMBLE';
\usepackage{amsmath}
\usepackage[normal]{xcolor}
\setlength{\mathindent}{0cm}
\definecolor{teal}{rgb}{0,0.5,0.5}
\definecolor{navy}{rgb}{0,0,0.5}
\definecolor{aqua}{rgb}{0,1,1}
\definecolor{lime}{rgb}{0,1,0}
\definecolor{maroon}{rgb}{0.5,0,0}
\definecolor{silver}{gray}{0.75}
PREAMBLE
  print $tempFile $this->{latexPreamble}."\n";
  print $tempFile '\begin{document}'."\n";
  print $tempFile '\pagestyle{empty}'."\n";
  print $tempFile "\\pagecolor".formatColorSpec($this->{bgColor})."\n";
  while (my ($key, $value) = each(%{$this->{hashedMathStrings}})) {
    $imageNumber++;
    print $tempFile "{\n";
    print $tempFile "\\color".formatColorSpec($this->{fgColors}{$value})."\n"
      if $this->{fgColors}{$value};
    if ($this->{sizes}{$value}) {
      print $tempFile "\\$this->{sizes}{$value}\n";
    } else {
      print $tempFile "\\$this->{latexFontSize}\n"
        if $this->{latexFontSize} ne "normalsize";
    }

    # analyze which environment to use
    my $environment = 'math';
    $environment = 'multline*' if $value =~ /\\\\/;
    $environment = 'eqnarray*' if $value =~ '&\s*=\s*&';
    #writeDebug("using $environment for $value");
    print $tempFile "\\begin{$environment}\\displaystyle $value\\end{$environment}\n";
    print $tempFile "}\n";

    print $tempFile "\\clearpage\n";

    # remember the filename it ends up
    $imageFile{$key} = $tempFile.$imageNumber.'.'.$this->{imageType};
  }
  print $tempFile "\\end{document}\n";

  my ($data, $exit);
  if ($this->{latex2Img})  {
    # run latex2html on the latex file we generated
    my $latex2ImgCmd = $this->{latex2Img} . ' %FILENAME|F%';
    $latex2ImgCmd .= " $this->{bgColor}";
    $latex2ImgCmd .= ' -D '.int(100)*$this->{scaleFactor};
    $latex2ImgCmd .= ' --'.$this->{imageType};

    #writeDebug("executing $latex2ImgCmd");
    ($data, $exit) = Foswiki::Sandbox->sysCommand($latex2ImgCmd, FILENAME=>"$tempFile");
  }
  else {
    $exit = 1;
    $data = "MathModePlugin cannot find the latex2img script. Please check the settings in configure";
  }
  #writeDebug("exit=$exit");
  #writeDebug("data=$data");
  if ($exit) {
    $msg = '<div class="foswikiAlert">Error during latex2img:<pre>'.
      $data.'</pre></div>';
  } else {
    # rename the files to the hash code, so we can uniquely identify them
    while ((my $key, my $value) = each(%imageFile)) {
      my $source = $value;
      my $target = $this->{topicPubDir}.'/'.$this->{imagePrefix}.$key.'.'.$this->{imageType};
      #writeDebug("source=$source, target=$target");
      #writeDebug("created new image $target");
      move($source, $target);# or die "can't move $source to $target: $@";
    }
  }

  # cleanup
  $this->{hashedMathStrings} =  {};
  #File::Temp::cleanup(); # SMELL: n/a in perl < 5.8.8
  close $tempFile;
  return $msg;
}

###############################################################################
# returns the arguments to the latex commands \color or \pagecolor
sub formatColorSpec {
  my $color = shift;

  # try to auto-detect the color spec
  return "{$color}" if $color =~ /^[a-zA-Z]+$/; # named
  return "[HTML]{$color}" if $color =~ /^[a-fA-F0-9]{6}$/; # named
  return "$color";
}

1;
