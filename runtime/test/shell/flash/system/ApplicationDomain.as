package flash.system
{
    import avmplus.Domain;
    import flash.utils.ByteArray;

    /**
     * avmshell has no flash.system.ApplicationDomain. This covers what as3pb and
     * its benchmark use, on top of avmshell's avmplus.Domain. Compile it into
     * avmshell builds only.
     */
    public final class ApplicationDomain
    {
        private static var _current:ApplicationDomain;

        public static function get MIN_DOMAIN_MEMORY_LENGTH():uint
        {
            return Domain.MIN_DOMAIN_MEMORY_LENGTH;
        }

        public static function get currentDomain():ApplicationDomain
        {
            if (!_current)
                _current = new ApplicationDomain();
            return _current;
        }

        public function get domainMemory():ByteArray
        {
            return Domain.currentDomain.domainMemory;
        }

        public function set domainMemory(value:ByteArray):void
        {
            Domain.currentDomain.domainMemory = value;
        }
    }
}
