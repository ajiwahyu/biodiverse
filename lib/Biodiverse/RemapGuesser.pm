package Biodiverse::RemapGuesser;

# guesses appropriate remappings between labels.
# canonical examples:
#     mapping "genus_species" to "genus species"
#             "genus:species" to "genus_species"
#             "Genus_species" to "genus:species" etc.

use 5.010;
use strict;
use warnings;

use Text::Levenshtein qw(distance);

our $VERSION = '1.99_006';


sub new {
    my $class = shift;
    my $self = bless {}, $class;
    return $self;
}



    
# takes in two references to arrays of labels (existing_labels and new_labels)
# returns a hash mapping labels in the second list to labels in the first list
sub guess_remap {
    
    
    my $self = shift;
    my $args = shift || {};

    my $first_ref = $args->{"existing_labels"};
    my $second_ref = $args->{"new_labels"};
    
    my @first_labels = @{$first_ref};
    my @second_labels = @{$second_ref};


    # look for simple punctuation match
    my %quick_results = $self->attempt_quick_remap({
	"existing_labels" => \@first_labels,
	"new_labels" => \@second_labels,
   });
    
    if($quick_results{success}) {
	$quick_results{"quick"} = 1;
	say "[RemapGuesser] generated a quick remap";
	return wantarray ? %quick_results : \%quick_results;

    }

      
    my %remap;

    # assume that the labels have been uniformly deformed (i.e. they
    # differ according to a pattern (or at least by the same
    # distance))
    my $assume_uniform_deformation = 1;
    
    # also keep track of the furthest distance we have to accept,
    # and the mean distance, so we get an idea of how good this remap is.
    my $furthest_distance = 0;
    my $distance_sum = 0;

    
    my $accepted_distance;

    
    my $match_index;
    foreach my $label (@second_labels) {
        my $min_distance = distance($label, $first_labels[0]);
        my $closest_label = $first_labels[0];
	$match_index = 0;
	   
	# do the comparison ignoring leading and trailing
	# whitespace as this can cause match issues e.g. 'sp1 ' is
	# just as close to 'sp10' as 'sp1'
	my $stripped_label = $label;
	$stripped_label =~ s/^\s+|\s+$//g;
	
	# also do the comparison ignoring case because it seems
	# unlikely that someone would intentionally use case to
	# distinguish between labels, whereas having two versions
	# of the same data with different case conventions seems
	# more likely. e.g. GenusSpecies1 -> genus_species1
	$stripped_label = lc($stripped_label);

	
        # find the closest match
        foreach my $i (0..$#first_labels) {
	    my $comparison_label = $first_labels[$i];
	   
	    my $stripped_comparison_label = $comparison_label;
	    $stripped_comparison_label =~ s/^\s+|\s+$//g;

	    $stripped_comparison_label = lc($stripped_comparison_label);

            my $this_distance = distance($stripped_label, $stripped_comparison_label);
            if($this_distance <= $min_distance) {
                $min_distance = $this_distance;
                $closest_label = $comparison_label;
		$match_index = $i;

		# if we've previously accepted a match of this distance
		# and we're assuming uniform deformation, we can end the run here.
		if($assume_uniform_deformation && defined $accepted_distance
		   && $this_distance == $accepted_distance) {
		    last;
		}
            }
        }

        $furthest_distance = $min_distance if($min_distance > $furthest_distance);
	$distance_sum += $min_distance;
	$accepted_distance = $min_distance;
        $remap{$label} = $closest_label;

	# now remove the match we made from first_labels
	splice(@first_labels, $match_index, 1);
    }

    my $mean_distance;

    # need to check if it's 0 to protect from empty list being passed in
    if($#second_labels+1 != 0) {
	$mean_distance = $distance_sum/($#second_labels+1);
    }
    

    say "[RemapGuesser] generated a full remap";


    my %results = (
	quick => 0,
	furthest_dist => $furthest_distance,
	mean_dist => $mean_distance,
	remap => \%remap,
	);
    
    return wantarray ? %results : \%results;
}



# tries to quickly match two lists of labels that differ only in
# punctuation/whitespace (not letters or digits)
sub attempt_quick_remap {
    my $class = shift;
    my $args = shift || {};
 
    my $first_ref = $args->{"existing_labels"};
    my $second_ref = $args->{"new_labels"};
    
    my @first_labels = @{$first_ref};
    my @second_labels = @{$second_ref};

    # create a hash mapping no punct to original string
    my %no_punct_lookup;
    for my $original (@first_labels) {
        my $fixed = $original;
	$fixed =~ s/[^\d\w]/_/g;
	$no_punct_lookup{$fixed} = $original;
    }
        

    # try to create a complete match
    my %remap;
    my $success = 1;
    foreach my $label (@second_labels) {
	my $no_punct = $label;
	$no_punct =~ s/[^\d\w]/_/g;

	if(exists $no_punct_lookup{$no_punct}) {
	    $remap{$label} = $no_punct_lookup{$no_punct};
	}
	else {
	    # couldn't find a match
	    $success = 0;
	    last;
 	}
    }


    my %results = (
	success => $success,
	remap => \%remap,
	);

    return wantarray ? %results : \%results;
}



1;
