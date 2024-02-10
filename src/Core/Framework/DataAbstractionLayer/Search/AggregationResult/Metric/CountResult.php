<?php declare(strict_types=1);

namespace Shopware\Core\Framework\DataAbstractionLayer\Search\AggregationResult\Metric;

use Shopware\Core\Framework\DataAbstractionLayer\Search\AggregationResult\AggregationResult;
use Shopware\Core\Framework\Log\Package;

/**
 * @final
 */
#[Package('core')]
class CountResult extends AggregationResult
{
    public function __construct(
        string $name,
        protected int $count
    ) {
        parent::__construct($name);
    }

    public function getCount(): int
    {
        return $this->count;
    }
}
