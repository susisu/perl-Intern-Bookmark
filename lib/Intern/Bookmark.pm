package Intern::Bookmark;

use strict;
use warnings;
use utf8;

use Class::Load qw(load_class);

use Intern::Bookmark::Config;
use Intern::Bookmark::Context;

sub as_psgi {
    my $class = shift;
    return sub {
        my $env = shift;
        return $class->run($env);
    };
}

sub run {
    my ($class, $env) = @_;

    my $context = Intern::Bookmark::Context->from_env($env);
    my $route = Intern::Bookmark::Config->router->match($env)
        or $context->throw(404);
    $context->req->path_parameters(%{$route->{parameters}});

    my $destination = $route->{destination}
        or $context->throw(404);
    $destination->{engine}
        or $context->throw(404);

    my $engine = join '::', __PACKAGE__, 'Engine', $destination->{engine};
    my $action = $destination->{action} || 'default';
    my $dispatch = "$engine#$action";

    load_class $engine;

    my $handler = $engine->can($action)
        or $context->throw(501);
    $engine->$handler($context);

    $context->res->headers->header(X_Dispatch => $dispatch);
    return $context->res->finalize;
}

1;
