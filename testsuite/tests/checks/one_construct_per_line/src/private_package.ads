private package Private_Package is --  NOFLAG
private    package Inner is        --  FLAG because the "private" here is the private part delimiter
end Inner;
end Private_Package;
